import json
import tempfile
import unittest
from pathlib import Path

import AiProjects


class ProjectCatalogTests(unittest.TestCase):
    def test_catalog_discovers_project_metadata_and_keeps_general_first(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            projects_root = Path(temporary_directory)
            jira_codex = projects_root / "jira" / ".codex"
            jira_codex.mkdir(parents=True)
            (jira_codex / "project.json").write_text(
                json.dumps({
                    "label": "Jira",
                    "description": "Issue management",
                }),
                encoding="utf-8",
            )
            english_codex = projects_root / "english" / ".codex"
            english_codex.mkdir(parents=True)

            catalog = AiProjects.project_catalog(projects_root)

            self.assertEqual(
                catalog["projects"],
                [
                    {
                        "id": "general",
                        "label": "General",
                        "description": "General AI chat",
                    },
                    {
                        "id": "english",
                        "label": "English",
                        "description": "",
                    },
                    {
                        "id": "jira",
                        "label": "Jira",
                        "description": "Issue management",
                    },
                ],
            )
            self.assertEqual(catalog["warnings"], [])

    def test_catalog_excludes_unsafe_or_malformed_projects(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            projects_root = Path(temporary_directory)
            (projects_root / "Invalid Name").mkdir()
            missing_codex = projects_root / "missing-codex"
            missing_codex.mkdir()
            broken_codex = projects_root / "broken" / ".codex"
            broken_codex.mkdir(parents=True)
            (broken_codex / "project.json").write_text("[", encoding="utf-8")
            target = projects_root / ".target"
            target.mkdir()
            (projects_root / "linked").symlink_to(target, target_is_directory=True)

            catalog = AiProjects.project_catalog(projects_root)

            self.assertEqual(
                [project["id"] for project in catalog["projects"]],
                ["general"],
            )
            self.assertEqual(len(catalog["warnings"]), 4)


if __name__ == "__main__":
    unittest.main()
