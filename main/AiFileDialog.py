#!/usr/bin/env python3
import os
import re
import stat
import subprocess
import sys
import tempfile
from pathlib import Path, PurePosixPath
from typing import BinaryIO

MAX_ARTIFACT_BYTES = 100 * 1024 * 1024
MAX_EXPORT_BYTES = 16 * 1024 * 1024
THREAD_ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
EXPORT_FILE_PATTERN = re.compile(r"^\.ai-export-[A-Za-z0-9_-]{1,80}\.md$")


class SaveFailure(Exception):
    pass


def callback(method: str, token: str, message: str | None = None) -> None:
    command = ["qs", "-c", "main", "ipc", "call", "ai", method, token]
    if message is not None:
        command.append(message)
    try:
        subprocess.run(
            command,
            check=False,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError:
        pass


def validated_relative_parts(relative_value: str) -> tuple[str, ...]:
    relative = PurePosixPath(relative_value)
    if relative.is_absolute() or not relative.parts:
        raise SaveFailure("The generated file path is invalid.")
    if any(part in ("", ".", "..") for part in relative.parts):
        raise SaveFailure("The generated file path is invalid.")
    return relative.parts


def open_regular_beneath(
    root_value: str, relative_value: str, maximum_bytes: int
) -> tuple[BinaryIO, os.stat_result]:
    parts = validated_relative_parts(relative_value)
    directory_flags = (
        os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
    )
    file_flags = os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW
    descriptors: list[int] = []
    try:
        current = os.open(root_value, directory_flags)
        descriptors.append(current)
        for component in parts[:-1]:
            current = os.open(component, directory_flags, dir_fd=current)
            descriptors.append(current)
        source_fd = os.open(parts[-1], file_flags, dir_fd=current)
        source_stat = os.fstat(source_fd)
        if not stat.S_ISREG(source_stat.st_mode):
            os.close(source_fd)
            raise SaveFailure("Only regular files can be saved.")
        if source_stat.st_size > maximum_bytes:
            os.close(source_fd)
            if maximum_bytes == MAX_ARTIFACT_BYTES:
                raise SaveFailure(
                    "This generated file exceeds the 100 MiB save limit."
                )
            raise SaveFailure("This conversation is too large to export.")
        return os.fdopen(source_fd, "rb"), source_stat
    except OSError as error:
        raise SaveFailure("The source file is no longer available.") from error
    finally:
        for descriptor in reversed(descriptors):
            os.close(descriptor)


def choose_destination(
    title: str, suggested_name: str, markdown: bool
) -> str | None:
    home = Path.home()
    suggested_path = home / suggested_name
    command = [
        "zenity",
        "--file-selection",
        "--save",
        "--confirm-overwrite",
        "--title=" + title,
        "--filename=" + str(suggested_path),
    ]
    if markdown:
        command.append("--file-filter=Markdown files | *.md")
    try:
        result = subprocess.run(
            command,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
    except FileNotFoundError as error:
        raise SaveFailure(
            "zenity is unavailable; install zenity to save files."
        ) from error
    if result.returncode == 1:
        return None
    if result.returncode != 0:
        raise SaveFailure("The save dialog could not be opened.")
    destination = (
        result.stdout[:-1] if result.stdout.endswith("\n") else result.stdout
    )
    if destination == "":
        return None
    return destination


def atomic_copy(
    source: BinaryIO,
    destination_value: str,
    maximum_bytes: int,
    oversized_message: str,
) -> None:
    destination = Path(destination_value)
    destination_directory = destination.parent
    if (
        not destination.is_absolute()
        or destination.name in ("", ".", "..")
        or not destination_directory.is_dir()
    ):
        raise SaveFailure("Choose a file inside an existing folder.")

    temporary_fd = -1
    temporary_path = ""
    try:
        temporary_fd, temporary_path = tempfile.mkstemp(
            prefix=".quickshell-ai-save-", dir=destination_directory
        )
        os.fchmod(temporary_fd, 0o600)
        with os.fdopen(temporary_fd, "wb", closefd=True) as destination_file:
            temporary_fd = -1
            remaining = maximum_bytes
            while True:
                chunk = source.read(min(1024 * 1024, remaining + 1))
                if not chunk:
                    break
                if len(chunk) > remaining:
                    raise SaveFailure(oversized_message)
                destination_file.write(chunk)
                remaining -= len(chunk)
            destination_file.flush()
            os.fsync(destination_file.fileno())
        os.replace(temporary_path, destination)
        temporary_path = ""
        directory_fd = os.open(
            destination_directory, os.O_RDONLY | os.O_DIRECTORY
        )
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    except OSError as error:
        raise SaveFailure("Could not write the selected destination.") from error
    finally:
        if temporary_fd >= 0:
            os.close(temporary_fd)
        if temporary_path:
            try:
                os.unlink(temporary_path)
            except OSError:
                pass


def export_conversation(arguments: list[str]) -> int:
    if len(arguments) != 4:
        return 2
    state_root, staging_name, suggested_name, token = arguments
    if EXPORT_FILE_PATTERN.fullmatch(staging_name) is None:
        callback(
            "exportFailed", token, "The conversation export could not be prepared."
        )
        return 1

    staging_path = Path(state_root) / staging_name
    try:
        source, _ = open_regular_beneath(
            state_root, staging_name, MAX_EXPORT_BYTES
        )
        try:
            os.unlink(staging_path)
        except OSError:
            pass
        with source:
            destination = choose_destination(
                "Export conversation", suggested_name, markdown=True
            )
            if destination is None:
                callback("exportCancelled", token)
                return 0
            atomic_copy(
                source,
                destination,
                MAX_EXPORT_BYTES,
                "This conversation is too large to export.",
            )
    except SaveFailure as error:
        callback("exportFailed", token, str(error))
        return 1
    finally:
        try:
            staging_path.unlink(missing_ok=True)
        except OSError:
            pass

    callback("exportCompleted", token)
    return 0


def save_artifact(arguments: list[str]) -> int:
    if len(arguments) != 4:
        return 2
    workspace, thread_id, relative_path, token = arguments
    if THREAD_ID_PATTERN.fullmatch(thread_id) is None:
        callback(
            "artifactSaveFailed",
            token,
            "The generated file is not managed by this chat.",
        )
        return 1

    try:
        managed_relative_path = (
            PurePosixPath("outputs") / thread_id / relative_path
        )
        source, _ = open_regular_beneath(
            workspace, managed_relative_path.as_posix(), MAX_ARTIFACT_BYTES
        )
        with source:
            destination = choose_destination(
                "Save generated file",
                PurePosixPath(relative_path).name,
                markdown=False,
            )
            if destination is None:
                callback("artifactSaveCancelled", token)
                return 0
            atomic_copy(
                source,
                destination,
                MAX_ARTIFACT_BYTES,
                "This generated file exceeds the 100 MiB save limit.",
            )
    except SaveFailure as error:
        callback("artifactSaveFailed", token, str(error))
        return 1

    callback("artifactSaveCompleted", token)
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        return 2
    mode = sys.argv[1]
    if mode == "export":
        return export_conversation(sys.argv[2:])
    if mode == "artifact":
        return save_artifact(sys.argv[2:])
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
