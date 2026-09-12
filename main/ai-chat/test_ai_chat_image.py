import base64
import contextlib
import io
import json
import os
import tempfile
import threading
import unittest
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from unittest.mock import patch

import AiChatImage
import AiOutputs


PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII="
)
GIF = base64.b64decode("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7")


def data_url(data: bytes, mime_type: str = "image/png") -> str:
    return "data:" + mime_type + ";base64," + base64.b64encode(data).decode("ascii")


class ImageSourceTests(unittest.TestCase):
    def test_data_urls_use_actual_raster_type(self) -> None:
        for data, mime_type in (
            (PNG, "image/png"),
            (GIF, "image/gif"),
            (b"\xff\xd8\xff\xe0\x00\x10JFIF\x00", "image/jpeg"),
            (b"RIFF\x14\x00\x00\x00WEBPVP8L\x08\x00\x00\x00", "image/webp"),
        ):
            with self.subTest(mime_type=mime_type):
                self.assertEqual(
                    AiChatImage.resolve_image("unused", "thread-1", data_url(data)),
                    data_url(data, mime_type),
                )
        self.assertEqual(
            AiChatImage.resolve_image(
                "unused", "thread-1", "data:image/png," + urllib.parse.quote_from_bytes(PNG)
            ),
            data_url(PNG),
        )

    def test_nonraster_and_malformed_data_urls_are_rejected(self) -> None:
        for source in (
            data_url(b"<svg xmlns='http://www.w3.org/2000/svg'></svg>"),
            data_url(b"<!DOCTYPE html><html>not an image</html>"),
            data_url(PNG, "image/svg+xml"),
            "data:image/png;base64,not base64!",
            "data:image/png;charset=utf-8;base64," + base64.b64encode(PNG).decode("ascii"),
            data_url(b"RIFF\x14\x00\x00\x00WAVEfmt "),
        ):
            with self.subTest(source=source):
                with self.assertRaises(AiChatImage.ImageError):
                    AiChatImage.resolve_image("unused", "thread-1", source)

    def test_managed_paths_accept_sandbox_and_percent_encoding(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory) / "outputs"
            AiOutputs.prepare_thread_outputs(str(root), "thread-1")
            nested = root / "thread-1" / "nested"
            nested.mkdir()
            (nested / "some image.png").write_bytes(PNG)
            for source in (
                "nested/some image.png",
                "nested%2Fsome%20image.png",
                "/home/agent/quickshell-ai-outputs/nested/some%20image.png",
                "sandbox:/home/agent/quickshell-ai-outputs/nested/some%20image.png",
            ):
                with self.subTest(source=source):
                    self.assertEqual(
                        AiChatImage.resolve_image(str(root), "thread-1", source),
                        data_url(PNG),
                    )

    def test_managed_urls_strip_suffixes_before_decoding_filenames(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory) / "outputs"
            AiOutputs.prepare_thread_outputs(str(root), "thread-1")
            thread = root / "thread-1"
            (thread / "plot.png").write_bytes(PNG)
            (thread / "plot?#.png").write_bytes(GIF)
            self.assertEqual(
                AiChatImage.resolve_image(str(root), "thread-1", "plot.png?raw=1#preview"),
                data_url(PNG),
            )
            self.assertEqual(
                AiChatImage.resolve_image(
                    str(root), "thread-1",
                    "sandbox:/home/agent/quickshell-ai-outputs/plot%3F%23.png#preview?raw=1",
                ),
                data_url(GIF, "image/gif"),
            )

    def test_managed_paths_cannot_escape_thread_or_follow_symlinks(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory) / "outputs"
            AiOutputs.prepare_thread_outputs(str(root), "thread-1")
            AiOutputs.prepare_thread_outputs(str(root), "thread-2")
            (root / "thread-2" / "secret.png").write_bytes(PNG)
            thread = root / "thread-1"
            os.symlink(root / "thread-2" / "secret.png", thread / "link.png")
            os.symlink(root / "thread-2", thread / "link-directory")
            os.symlink(root / "thread-2", root / "linked-thread")
            os.mkfifo(thread / "fifo")
            sources = (
                "../thread-2/secret.png",
                "%2e%2e%2fthread-2/secret.png",
                "/home/agent/quickshell-ai-outputs/../thread-2/secret.png",
                "sandbox:/home/agent/quickshell-ai-outputs/%2e%2e/thread-2/secret.png",
                "sandbox:/etc/passwd",
                "file:///etc/passwd",
                "ftp://localhost/image.png",
                "/etc/passwd",
                str(root / "thread-2" / "secret.png"),
                "//localhost/image.png",
                "link.png",
                "link-directory/secret.png",
                "fifo",
                "image%00.png",
            )
            for source in sources:
                with self.subTest(source=source):
                    with self.assertRaises(AiChatImage.ImageError):
                        AiChatImage.resolve_image(str(root), "thread-1", source)
            for thread_id in ("../thread-2", "linked-thread", "/thread-2"):
                with self.subTest(thread_id=thread_id):
                    with self.assertRaises(AiChatImage.ImageError):
                        AiChatImage.resolve_image(str(root), thread_id, "secret.png")
            with self.assertRaises(AiChatImage.ImageError):
                AiChatImage.resolve_image(str(root / "linked-thread"), "thread-1", "secret.png")

    def test_limits_apply_to_data_files_and_stdin(self) -> None:
        with patch.object(AiChatImage, "MAX_IMAGE_BYTES", len(PNG) - 1):
            with self.assertRaises(AiChatImage.ImageError):
                AiChatImage.resolve_image("unused", "thread-1", data_url(PNG))
            with tempfile.TemporaryDirectory() as root:
                AiOutputs.prepare_thread_outputs(root, "thread-1")
                (Path(root) / "thread-1" / "image.png").write_bytes(PNG)
                with self.assertRaises(AiChatImage.ImageError):
                    AiChatImage.resolve_image(root, "thread-1", "image.png")
        with patch.object(AiChatImage, "MAX_SOURCE_BYTES", 16):
            stdin = io.TextIOWrapper(io.BytesIO(b"x" * 17))
            stdout = io.StringIO()
            with patch("sys.stdin", stdin), patch("sys.argv", ["AiChatImage.py", "unused", "thread-1"]):
                with contextlib.redirect_stdout(stdout):
                    self.assertEqual(AiChatImage.main(), 1)
            self.assertEqual(set(json.loads(stdout.getvalue())), {"error"})

    def test_cli_outputs_only_normalized_source_or_safe_error(self) -> None:
        for source, expected_status in ((data_url(PNG), 0), ("file:///private/secret.png", 1)):
            stdin = io.TextIOWrapper(io.BytesIO(source.encode("utf-8")))
            stdout = io.StringIO()
            with patch("sys.stdin", stdin), patch("sys.argv", ["AiChatImage.py", "unused", "thread-1"]):
                with contextlib.redirect_stdout(stdout):
                    self.assertEqual(AiChatImage.main(), expected_status)
            result = json.loads(stdout.getvalue())
            if expected_status == 0:
                self.assertEqual(result, {"source": data_url(PNG)})
            else:
                self.assertEqual(set(result), {"error"})
                self.assertNotIn("private", result["error"])


class NetworkImageTests(unittest.TestCase):
    def setUp(self) -> None:
        self.requests = []
        requests = self.requests

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                requests.append((self.path, dict(self.headers)))
                if self.path.startswith("/redirect?"):
                    self.send_response(302)
                    self.send_header("Location", urllib.parse.unquote(self.path.split("?", 1)[1]))
                    self.end_headers()
                    return
                self.send_response(200)
                if self.path == "/oversized-header":
                    self.send_header("Content-Length", "99999999")
                self.send_header("Content-Type", "image/png")
                self.end_headers()
                if self.path == "/oversized-body":
                    self.wfile.write(PNG + b"x" * 128)
                elif self.path == "/html":
                    self.wfile.write(b"<html>not an image</html>")
                else:
                    self.wfile.write(PNG)

            def log_message(self, *args):
                pass

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.server_thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.server_thread.start()
        self.base_url = "http://127.0.0.1:" + str(self.server.server_port)

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.server_thread.join()

    def test_http_download_and_http_redirect_produce_inline_raster(self) -> None:
        for path in ("/image", "/redirect?" + urllib.parse.quote(self.base_url + "/image", safe="")):
            self.assertEqual(
                AiChatImage.resolve_image("unused", "thread-1", self.base_url + path),
                data_url(PNG),
            )
        for _, headers in self.requests:
            self.assertNotIn("Authorization", headers)
            self.assertNotIn("Proxy-Authorization", headers)
            self.assertNotIn("Cookie", headers)

    def test_redirects_cannot_load_local_schemes_or_send_credentials(self) -> None:
        for target in (
            "file:///etc/passwd",
            "ftp://127.0.0.1/image.png",
            data_url(PNG),
            self.base_url.replace("http://", "http://user:secret@") + "/image",
        ):
            with self.subTest(target=target):
                before = len(self.requests)
                with self.assertRaises(AiChatImage.ImageError):
                    AiChatImage.resolve_image(
                        "unused", "thread-1", self.base_url + "/redirect?" + urllib.parse.quote(target, safe="")
                    )
                self.assertEqual(len(self.requests), before + 1)
        before = len(self.requests)
        with self.assertRaises(AiChatImage.ImageError):
            AiChatImage.resolve_image(
                "unused", "thread-1", self.base_url.replace("http://", "http://user:secret@") + "/image"
            )
        self.assertEqual(len(self.requests), before)

    def test_network_checks_real_content_and_bounds_with_or_without_length(self) -> None:
        with patch.object(AiChatImage, "MAX_IMAGE_BYTES", 128):
            for path in ("/oversized-header", "/oversized-body", "/html"):
                with self.subTest(path=path):
                    with self.assertRaises(AiChatImage.ImageError):
                        AiChatImage.resolve_image("unused", "thread-1", self.base_url + path)


if __name__ == "__main__":
    unittest.main()
