import io
import os
import stat
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import AiFileDialog
import AiOutputs


class ManagedOutputTests(unittest.TestCase):
    def test_index_includes_only_regular_files_within_limit(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            output_root = Path(temporary_directory) / "outputs"
            AiOutputs.prepare_thread_outputs(str(output_root), "thread-1")
            thread_root = output_root / "thread-1"
            nested = thread_root / "nested"
            nested.mkdir()
            (thread_root / "result.txt").write_bytes(b"result\n")
            (nested / "details.json").write_bytes(b"{}\n")
            oversized = thread_root / "oversized.bin"
            with oversized.open("wb") as oversized_file:
                oversized_file.truncate(AiOutputs.MAX_FILE_BYTES + 1)
            os.symlink("/etc/passwd", thread_root / "outside-file")
            os.symlink("/tmp", thread_root / "outside-directory")

            indexed = AiOutputs.indexed_files(str(output_root), "thread-1")

            self.assertEqual(
                [item["relativePath"] for item in indexed],
                ["nested/details.json", "result.txt"],
            )
            self.assertEqual(stat.S_IMODE(output_root.stat().st_mode), 0o700)
            self.assertEqual(stat.S_IMODE(thread_root.stat().st_mode), 0o700)

    def test_delete_output_file_removes_only_the_requested_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            output_root = Path(temporary_directory) / "outputs"
            AiOutputs.prepare_thread_outputs(str(output_root), "thread-1")
            thread_root = output_root / "thread-1"
            nested = thread_root / "nested"
            nested.mkdir()
            requested_file = nested / "result.txt"
            requested_file.write_text("result\n", encoding="utf-8")
            retained_file = thread_root / "keep.txt"
            retained_file.write_text("keep\n", encoding="utf-8")

            AiOutputs.delete_output_file(
                str(output_root), "thread-1", "nested/result.txt"
            )

            self.assertFalse(requested_file.exists())
            self.assertEqual(retained_file.read_text(encoding="utf-8"), "keep\n")

    def test_delete_output_file_rejects_unmanaged_paths(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            output_root = Path(temporary_directory) / "outputs"
            AiOutputs.prepare_thread_outputs(str(output_root), "thread-1")
            thread_root = output_root / "thread-1"
            outside_file = output_root / "outside.txt"
            outside_file.write_text("outside\n", encoding="utf-8")
            os.symlink(outside_file, thread_root / "outside-link")
            (thread_root / "directory").mkdir()

            for relative_path in (
                "../outside.txt",
                "outside-link",
                "directory",
            ):
                with self.subTest(relative_path=relative_path):
                    with self.assertRaises((OSError, ValueError)):
                        AiOutputs.delete_output_file(
                            str(output_root), "thread-1", relative_path
                        )

            self.assertEqual(outside_file.read_text(encoding="utf-8"), "outside\n")

    def test_source_open_rejects_escape_and_symlink_paths(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            workspace = Path(temporary_directory) / "workspace"
            source_path = workspace / "outputs" / "thread-1" / "result.txt"
            source_path.parent.mkdir(parents=True)
            source_path.write_bytes(b"managed\n")
            os.symlink("/etc/passwd", source_path.parent / "outside")

            source, source_stat = AiFileDialog.open_regular_beneath(
                str(workspace), "outputs/thread-1/result.txt", 1024
            )
            with source:
                self.assertEqual(source.read(), b"managed\n")
            self.assertEqual(source_stat.st_size, 8)

            for relative_path in (
                "outputs/thread-1/outside",
                "outputs/thread-1/../result.txt",
                "/etc/passwd",
            ):
                with self.subTest(relative_path=relative_path):
                    with self.assertRaises(AiFileDialog.SaveFailure):
                        AiFileDialog.open_regular_beneath(
                            str(workspace), relative_path, 1024
                        )

    def test_atomic_copy_preserves_destination_when_source_exceeds_limit(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            destination = Path(temporary_directory) / "saved.txt"
            destination.write_bytes(b"original")
            AiFileDialog.atomic_copy(
                io.BytesIO(b"updated"), str(destination), 7, "too large"
            )
            self.assertEqual(destination.read_bytes(), b"updated")
            self.assertEqual(stat.S_IMODE(destination.stat().st_mode), 0o600)

            with self.assertRaisesRegex(AiFileDialog.SaveFailure, "too large"):
                AiFileDialog.atomic_copy(
                    io.BytesIO(b"oversized"), str(destination), 4, "too large"
                )

            self.assertEqual(destination.read_bytes(), b"updated")
            self.assertEqual(
                list(Path(temporary_directory).glob(".quickshell-ai-save-*")), []
            )

            with self.assertRaises(AiFileDialog.SaveFailure):
                AiFileDialog.atomic_copy(
                    io.BytesIO(b"data"), "relative.txt", 4, "too large"
                )

    def test_export_cancellation_removes_staging_without_failure(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            staging_name = ".ai-export-token.md"
            staging_path = Path(temporary_directory) / staging_name
            staging_path.write_text("# Conversation\n", encoding="utf-8")

            with (
                patch.object(AiFileDialog, "choose_destination", return_value=None),
                patch.object(AiFileDialog, "callback") as callback,
            ):
                result = AiFileDialog.export_conversation(
                    [temporary_directory, staging_name, "conversation.md", "token"]
                )

            self.assertEqual(result, 0)
            self.assertFalse(staging_path.exists())
            callback.assert_called_once_with("exportCancelled", "token")

    def test_export_failure_removes_staging(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            staging_name = ".ai-export-oversized.md"
            staging_path = Path(temporary_directory) / staging_name
            with staging_path.open("wb") as staging_file:
                staging_file.truncate(AiFileDialog.MAX_EXPORT_BYTES + 1)

            with patch.object(AiFileDialog, "callback") as callback:
                result = AiFileDialog.export_conversation(
                    [
                        temporary_directory,
                        staging_name,
                        "conversation.md",
                        "token",
                    ]
                )

            self.assertEqual(result, 1)
            self.assertFalse(staging_path.exists())
            callback.assert_called_once_with(
                "exportFailed",
                "token",
                "This conversation is too large to export.",
            )


if __name__ == "__main__":
    unittest.main()
