#!/usr/bin/env python3
import json
import mimetypes
import os
import re
import shutil
import stat
import sys
from pathlib import Path, PurePosixPath

MAX_FILE_BYTES = 100 * 1024 * 1024
THREAD_ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
DIRECTORY_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
FILE_FLAGS = os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW


def validate_thread_id(thread_id: str) -> None:
    if THREAD_ID_PATTERN.fullmatch(thread_id) is None:
        raise ValueError("invalid thread ID")


def output_path_parts(relative_path: str) -> tuple[str, ...]:
    parts = relative_path.split("/")
    if (
        not relative_path
        or relative_path.startswith("/")
        or any(part in ("", ".", "..") for part in parts)
    ):
        raise ValueError("invalid output path")
    return tuple(parts)


def managed_output_root(root_value: str) -> Path:
    root = Path(root_value)
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    root_fd = os.open(root, DIRECTORY_FLAGS)
    try:
        root_stat = os.fstat(root_fd)
        if not stat.S_ISDIR(root_stat.st_mode):
            raise ValueError("invalid output root")
        os.fchmod(root_fd, 0o700)
    finally:
        os.close(root_fd)
    return root


def scan_directory(
    directory_fd: int, relative_directory: PurePosixPath
) -> list[dict[str, object]]:
    files: list[dict[str, object]] = []
    for name in os.listdir(directory_fd):
        try:
            entry_stat = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
        except OSError:
            continue
        relative_path = relative_directory / name
        if stat.S_ISDIR(entry_stat.st_mode):
            try:
                child_fd = os.open(name, DIRECTORY_FLAGS, dir_fd=directory_fd)
            except OSError:
                continue
            try:
                files.extend(scan_directory(child_fd, relative_path))
            finally:
                os.close(child_fd)
            continue
        if not stat.S_ISREG(entry_stat.st_mode):
            continue
        try:
            file_fd = os.open(name, FILE_FLAGS, dir_fd=directory_fd)
        except OSError:
            continue
        try:
            file_stat = os.fstat(file_fd)
        finally:
            os.close(file_fd)
        if not stat.S_ISREG(file_stat.st_mode) or file_stat.st_size > MAX_FILE_BYTES:
            continue
        mime_type, _ = mimetypes.guess_type(name, strict=False)
        files.append({
            "relativePath": relative_path.as_posix(),
            "size": file_stat.st_size,
            "mimeType": mime_type or "",
        })
    return files


def indexed_files(root_value: str, thread_id: str) -> list[dict[str, object]]:
    validate_thread_id(thread_id)
    root = managed_output_root(root_value)
    root_fd = os.open(root, DIRECTORY_FLAGS)
    try:
        try:
            thread_fd = os.open(thread_id, DIRECTORY_FLAGS, dir_fd=root_fd)
        except FileNotFoundError:
            return []
        try:
            files = scan_directory(thread_fd, PurePosixPath())
        finally:
            os.close(thread_fd)
    finally:
        os.close(root_fd)
    files.sort(key=lambda item: str(item["relativePath"]).casefold())
    return files


def prepare_thread_outputs(root_value: str, thread_id: str) -> None:
    validate_thread_id(thread_id)
    root = managed_output_root(root_value)
    root_fd = os.open(root, DIRECTORY_FLAGS)
    try:
        try:
            os.mkdir(thread_id, mode=0o700, dir_fd=root_fd)
        except FileExistsError:
            pass
        thread_fd = os.open(thread_id, DIRECTORY_FLAGS, dir_fd=root_fd)
        try:
            os.fchmod(thread_fd, 0o700)
        finally:
            os.close(thread_fd)
    finally:
        os.close(root_fd)


def print_index(root_value: str, thread_id: str) -> None:
    for item in indexed_files(root_value, thread_id):
        print(json.dumps(item, ensure_ascii=False, separators=(",", ":")))


def delete_output_file(
    root_value: str, thread_id: str, relative_path: str
) -> None:
    validate_thread_id(thread_id)
    path_parts = output_path_parts(relative_path)
    root = managed_output_root(root_value)
    root_fd = os.open(root, DIRECTORY_FLAGS)
    try:
        try:
            directory_fd = os.open(thread_id, DIRECTORY_FLAGS, dir_fd=root_fd)
        except FileNotFoundError:
            return
        try:
            for component in path_parts[:-1]:
                try:
                    child_fd = os.open(
                        component, DIRECTORY_FLAGS, dir_fd=directory_fd
                    )
                except FileNotFoundError:
                    return
                os.close(directory_fd)
                directory_fd = child_fd

            try:
                file_fd = os.open(
                    path_parts[-1], FILE_FLAGS, dir_fd=directory_fd
                )
            except FileNotFoundError:
                return
            try:
                if not stat.S_ISREG(os.fstat(file_fd).st_mode):
                    raise ValueError("output path is not a regular file")
            finally:
                os.close(file_fd)
            os.unlink(path_parts[-1], dir_fd=directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        os.close(root_fd)


def delete_thread_outputs(root_value: str, thread_id: str) -> None:
    validate_thread_id(thread_id)
    root = managed_output_root(root_value)
    root_fd = os.open(root, DIRECTORY_FLAGS)
    try:
        try:
            thread_stat = os.stat(
                thread_id, dir_fd=root_fd, follow_symlinks=False
            )
        except FileNotFoundError:
            return
        if not stat.S_ISDIR(thread_stat.st_mode):
            raise ValueError("invalid thread output root")
        shutil.rmtree(thread_id, dir_fd=root_fd)
    finally:
        os.close(root_fd)


def main() -> int:
    if len(sys.argv) < 3:
        return 2
    mode = sys.argv[1]
    root_value = sys.argv[2]
    try:
        if mode == "ensure":
            if len(sys.argv) != 3:
                return 2
            managed_output_root(root_value)
            return 0
        if mode == "delete-file":
            if len(sys.argv) != 5:
                return 2
            delete_output_file(root_value, sys.argv[3], sys.argv[4])
            return 0
        if len(sys.argv) != 4:
            return 2
        thread_id = sys.argv[3]
        if mode == "index":
            print_index(root_value, thread_id)
        elif mode == "prepare":
            prepare_thread_outputs(root_value, thread_id)
        elif mode == "delete":
            delete_thread_outputs(root_value, thread_id)
        else:
            return 2
    except (OSError, ValueError):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
