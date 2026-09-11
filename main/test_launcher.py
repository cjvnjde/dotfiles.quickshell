#!/usr/bin/env python3
"""Run isolated picker interaction tests on X11/Xwayland, including GNOME.

Only the temporary copy swaps the layer-shell attachment for X11 keyboard focus.
The real picker, search logic, and palette are copied unchanged otherwise. Launches
are intercepted by LauncherTest.qml; system theme and launcher state are isolated.
"""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--screenshots", type=Path, help="Save dark/light picker PNGs here")
    args = parser.parse_args()
    source = Path(__file__).resolve().parent
    expected_passes = len(re.findall(r"function test_", (source / "LauncherTest.qml").read_text())) + 1

    with tempfile.TemporaryDirectory(prefix="quickshell-launcher-test-") as temporary:
        config = Path(temporary)
        for name in ("LauncherSearch.js", "Theme.qml"):
            shutil.copy2(source / name, config / name)
        shutil.copy2(source / "LauncherTest.qml", config / "shell.qml")
        launcher = (source / "AppLauncher.qml").read_text()
        launcher = launcher.replace("import Quickshell.Wayland\n", "")
        launcher = launcher.replace("        WlrLayershell.layer: WlrLayer.Overlay\n", "")
        launcher = launcher.replace(
            "        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive\n",
            "        focusable: true\n",
        )
        (config / "AppLauncher.qml").write_text(launcher)
        (config / "SystemTheme.qml").write_text(
            'pragma Singleton\nimport QtQuick\nimport Quickshell\n'
            'QtObject { readonly property bool dark: Quickshell.env("LAUNCHER_TEST_MODE") === "dark" }\n'
        )
        (config / "qmldir").write_text(
            "singleton Theme 1.0 Theme.qml\n"
            "singleton SystemTheme 1.0 SystemTheme.qml\n"
            "AppLauncher 1.0 AppLauncher.qml\n"
        )
        environment = dict(os.environ, QT_QPA_PLATFORM="xcb", QT_QUICK_BACKEND="software",
                           XDG_STATE_HOME=str(config / "state"), XDG_CACHE_HOME=str(config / "cache"))
        environment.pop("WAYLAND_DISPLAY", None)
        environment.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
        environment.pop("LAUNCHER_SCREENSHOT_DIR", None)

        for mode in ("dark", "light"):
            environment["LAUNCHER_TEST_MODE"] = mode
            if args.screenshots:
                output = args.screenshots.resolve() / mode
                output.mkdir(parents=True, exist_ok=True)
                environment["LAUNCHER_SCREENSHOT_DIR"] = str(output)
            result = subprocess.run(
                ["qs", "-p", str(config), "--no-color"], env=environment,
                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30,
            )
            match = re.search(r"LAUNCHER_TEST_RESULTS (\{.*\})", result.stdout)
            counts = json.loads(match[1]) if match else {}
            if result.returncode or counts != {"passed": expected_passes, "failed": 0, "skipped": 0}:
                raise SystemExit(f"{mode} launcher tests failed:\n{result.stdout}")
            if args.screenshots and not (output / "launcher.png").is_file():
                raise SystemExit(f"{mode} screenshot missing:\n{result.stdout}")
            print(f"{mode}: {counts['passed']} checks passed")


if __name__ == "__main__":
    main()
