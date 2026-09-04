#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path

PROJECT_ID_PATTERN = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$")
GENERAL_PROJECT = {
    "id": "general",
    "label": "General",
    "description": "General AI chat",
}


def project_catalog(projects_root: Path) -> dict[str, list]:
    projects = [GENERAL_PROJECT.copy()]
    warnings: list[str] = []
    if not projects_root.exists():
        return {"projects": projects, "warnings": warnings}
    if not projects_root.is_dir() or projects_root.is_symlink():
        raise ValueError("AI projects path must be a directory")

    for project_directory in sorted(projects_root.iterdir(), key=lambda path: path.name):
        project_id = project_directory.name
        if project_id.startswith("."):
            continue
        if not PROJECT_ID_PATTERN.fullmatch(project_id) or project_id == "general":
            warnings.append(f"Ignored invalid project ID: {project_id}")
            continue
        if not project_directory.is_dir() or project_directory.is_symlink():
            warnings.append(f"Ignored non-directory project: {project_id}")
            continue

        codex_directory = project_directory / ".codex"
        if not codex_directory.is_dir() or codex_directory.is_symlink():
            warnings.append(f"Ignored project without .codex directory: {project_id}")
            continue

        metadata_path = codex_directory / "project.json"
        metadata = {}
        if metadata_path.exists():
            if not metadata_path.is_file() or metadata_path.is_symlink():
                warnings.append(f"Ignored unsafe project metadata: {project_id}")
                continue
            try:
                metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                warnings.append(f"Ignored invalid project metadata: {project_id}")
                continue
            if not isinstance(metadata, dict):
                warnings.append(f"Ignored invalid project metadata: {project_id}")
                continue

        label = metadata.get("label", project_id.replace("-", " ").title())
        description = metadata.get("description", "")
        if not isinstance(label, str) or not label.strip():
            warnings.append(f"Ignored project with invalid label: {project_id}")
            continue
        if not isinstance(description, str):
            warnings.append(f"Ignored project with invalid description: {project_id}")
            continue

        projects.append({
            "id": project_id,
            "label": label.strip(),
            "description": description.strip(),
        })

    return {"projects": projects, "warnings": warnings}


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: AiProjects.py <projects-directory>", file=sys.stderr)
        return 2

    try:
        catalog = project_catalog(Path(sys.argv[1]))
    except (OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 1

    print(json.dumps(catalog, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
