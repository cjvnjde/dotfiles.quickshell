#!/usr/bin/env python3
"""Resolve assistant image sources to bounded, raster-only inline data URLs."""

import base64
import binascii
import json
import os
import stat
import sys
import urllib.error
import urllib.parse
import urllib.request

from AiOutputs import DIRECTORY_FLAGS, FILE_FLAGS, output_path_parts, validate_thread_id

MAX_IMAGE_BYTES = 20 * 1024 * 1024
MAX_SOURCE_BYTES = MAX_IMAGE_BYTES * 3 + 1024
NETWORK_TIMEOUT_SECONDS = 20
SANDBOX_OUTPUT_PREFIX = "/home/agent/quickshell-ai-outputs/"
RASTER_MIME_TYPES = {"image/png", "image/jpeg", "image/gif", "image/webp"}


class ImageError(ValueError):
    pass


def raster_mime_type(data: bytes) -> str:
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith((b"GIF87a", b"GIF89a")):
        return "image/gif"
    if len(data) >= 16 and data[:4] == b"RIFF" and data[8:12] == b"WEBP" and data[12:16] in (b"VP8 ", b"VP8L", b"VP8X"):
        return "image/webp"
    raise ImageError("Only PNG, JPEG, GIF and WebP images are supported")


def bounded_read(stream) -> bytes:
    data = stream.read(MAX_IMAGE_BYTES + 1)
    if len(data) > MAX_IMAGE_BYTES:
        raise ImageError("Image exceeds the 20 MiB limit")
    return data


def decode_data_url(source: str) -> bytes:
    metadata, separator, payload = source[5:].partition(",")
    fields = metadata.lower().split(";")
    if not separator or fields[0] not in RASTER_MIME_TYPES:
        raise ImageError("Unsupported image data URL")
    if fields[1:] not in ([], ["base64"]):
        raise ImageError("Unsupported image data encoding")
    try:
        encoded = urllib.parse.unquote_to_bytes(payload)
        if fields[1:]:
            if len(encoded) > ((MAX_IMAGE_BYTES + 2) // 3) * 4:
                raise ImageError("Image exceeds the 20 MiB limit")
            data = base64.b64decode(encoded, validate=True)
        else:
            data = encoded
    except (binascii.Error, UnicodeError) as error:
        raise ImageError("Invalid image data encoding") from error
    if len(data) > MAX_IMAGE_BYTES:
        raise ImageError("Image exceeds the 20 MiB limit")
    return data


def validate_network_url(source: str) -> None:
    try:
        parsed = urllib.parse.urlsplit(source)
        if (
            parsed.scheme.lower() not in ("http", "https")
            or not parsed.hostname
            or parsed.username is not None
            or parsed.password is not None
            or any(ord(character) < 32 or ord(character) == 127 for character in source)
        ):
            raise ValueError
        parsed.port
    except ValueError as error:
        raise ImageError("Invalid or unsupported image URL") from error


class HttpOnlyRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, new_url):
        try:
            validate_network_url(new_url)
        except ImageError:
            response.close()
            raise
        return super().redirect_request(request, response, code, message, headers, new_url)


def download_image(source: str) -> bytes:
    validate_network_url(source)
    # Do not inherit proxy credentials, cookies, or authentication handlers.
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({}), HttpOnlyRedirectHandler()
    )
    request = urllib.request.Request(source, headers={"Accept": "image/png,image/jpeg,image/gif,image/webp"})
    try:
        with opener.open(request, timeout=NETWORK_TIMEOUT_SECONDS) as response:
            content_length = response.headers.get("Content-Length")
            if content_length is not None and int(content_length) > MAX_IMAGE_BYTES:
                raise ImageError("Image exceeds the 20 MiB limit")
            return bounded_read(response)
    except ImageError:
        raise
    except urllib.error.HTTPError as error:
        error.close()
        raise ImageError("Unable to download image") from error
    except (OSError, ValueError, urllib.error.URLError) as error:
        raise ImageError("Unable to download image") from error


def managed_path_parts(source: str) -> tuple[str, ...]:
    try:
        path = urllib.parse.unquote(source, encoding="utf-8", errors="strict")
        if path.startswith("sandbox:"):
            path = path[len("sandbox:"):]
            if not path.startswith(SANDBOX_OUTPUT_PREFIX):
                raise ValueError
        if path.startswith(SANDBOX_OUTPUT_PREFIX):
            path = path[len(SANDBOX_OUTPUT_PREFIX):]
        if "\x00" in path or "\\" in path or ":" in path:
            raise ValueError
        return output_path_parts(path)
    except ValueError as error:
        raise ImageError("Image path is outside managed thread outputs") from error


def read_managed_image(root_value: str, thread_id: str, source: str) -> bytes:
    parts = managed_path_parts(source)
    try:
        validate_thread_id(thread_id)
        root_fd = os.open(root_value, DIRECTORY_FLAGS)
        try:
            directory_fd = os.open(thread_id, DIRECTORY_FLAGS, dir_fd=root_fd)
            try:
                for component in parts[:-1]:
                    child_fd = os.open(component, DIRECTORY_FLAGS, dir_fd=directory_fd)
                    os.close(directory_fd)
                    directory_fd = child_fd
                file_fd = os.open(parts[-1], FILE_FLAGS | os.O_NONBLOCK, dir_fd=directory_fd)
                try:
                    file_stat = os.fstat(file_fd)
                    if not stat.S_ISREG(file_stat.st_mode):
                        raise ImageError("Image output is not a regular file")
                    if file_stat.st_size > MAX_IMAGE_BYTES:
                        raise ImageError("Image exceeds the 20 MiB limit")
                    with os.fdopen(file_fd, "rb", closefd=False) as image_file:
                        return bounded_read(image_file)
                finally:
                    os.close(file_fd)
            finally:
                os.close(directory_fd)
        finally:
            os.close(root_fd)
    except ImageError:
        raise
    except FileNotFoundError as error:
        raise ImageError("Image output is not available yet") from error
    except (OSError, ValueError) as error:
        raise ImageError("Unable to read managed image output") from error


def resolve_image(root_value: str, thread_id: str, source: str) -> str:
    if not source or len(source.encode("utf-8")) > MAX_SOURCE_BYTES:
        raise ImageError("Image source is empty or too large")
    if source[:5].lower() == "data:":
        data = decode_data_url(source)
    elif urllib.parse.urlsplit(source).scheme.lower() in ("http", "https"):
        data = download_image(source)
    else:
        data = read_managed_image(root_value, thread_id, source)
    mime_type = raster_mime_type(data)
    return "data:" + mime_type + ";base64," + base64.b64encode(data).decode("ascii")


def main() -> int:
    try:
        if len(sys.argv) != 3:
            raise ImageError("Expected output directory and thread ID")
        source_bytes = sys.stdin.buffer.read(MAX_SOURCE_BYTES + 1)
        if len(source_bytes) > MAX_SOURCE_BYTES:
            raise ImageError("Image source is too large")
        source = source_bytes.decode("utf-8").strip()
        result = {"source": resolve_image(sys.argv[1], sys.argv[2], source)}
        exit_code = 0
    except ImageError as error:
        result = {"error": str(error)}
        exit_code = 1
    except Exception:
        # Never expose URLs, filesystem paths, credentials or response bodies.
        result = {"error": "Unable to load image"}
        exit_code = 1
    print(json.dumps(result, separators=(",", ":")))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
