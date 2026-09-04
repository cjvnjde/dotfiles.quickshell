pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    property string language: "--"
    property int activeIndex: -1
    property var layouts: []
    property string switchError: ""
    readonly property bool switching: layoutSwitch.running

    function languageCode(layout) {
        const normalized = String(layout || "").trim().toLowerCase();
        if (!normalized) {
            return "--";
        }
        if (normalized === "us" || normalized === "gb" || normalized.startsWith("english")) {
            return "EN";
        }
        if (normalized === "ru" || normalized.startsWith("russian")) {
            return "RU";
        }

        return normalized.slice(0, 2).toUpperCase();
    }

    function setLayout(layout) {
        language = languageCode(layout);
    }

    function updateDevices(devices) {
        const keyboards = devices.keyboards || [];
        const keyboard = keyboards.find(device => device.main) || keyboards[0];
        if (!keyboard) {
            activeIndex = -1;
            layouts = [];
            language = "--";
            return;
        }

        const configuredLayouts = String(keyboard.layout || "").split(",");
        const configuredVariants = String(keyboard.variant || "").split(",");
        const nextLayouts = [];
        for (let index = 0; index < configuredLayouts.length; index++) {
            const code = configuredLayouts[index].trim();
            if (!code) {
                continue;
            }

            nextLayouts.push({
                index,
                code,
                variant: (configuredVariants[index] || "").trim(),
                language: languageCode(code)
            });
        }

        const index = Number(keyboard.active_layout_index);
        activeIndex = Number.isInteger(index) ? index : -1;
        layouts = nextLayouts;
        const activeLayout = nextLayouts.find(layout => layout.index === activeIndex);
        language = activeLayout
            ? activeLayout.language : languageCode(keyboard.active_keymap);
    }

    function refresh() {
        if (!layoutQuery.running) {
            layoutQuery.running = true;
        }
    }

    function switchLayout(index) {
        const targetIndex = Number(index);
        if (!Number.isInteger(targetIndex)
                || targetIndex < 0
                || targetIndex === activeIndex
                || layoutSwitch.running) {
            return;
        }

        switchError = "";
        layoutSwitch.command = [
            "hyprctl",
            "switchxkblayout",
            "all",
            String(targetIndex)
        ];
        layoutSwitch.running = true;
    }

    Component.onCompleted: refresh()

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "activelayout") {
                return;
            }

            const fields = event.parse(2);
            if (fields.length > 1) {
                root.setLayout(fields[1]);
            }
            root.refresh();
        }
    }

    Process {
        id: layoutQuery
        command: ["hyprctl", "-j", "devices"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.updateDevices(JSON.parse(text));
                } catch (error) {
                    console.warn("Failed to read keyboard layouts:", error);
                }
            }
        }
    }

    Process {
        id: layoutSwitch

        stdout: StdioCollector {
            id: layoutSwitchOutput
        }
        stderr: StdioCollector {
            id: layoutSwitchError
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.switchError = "Could not switch keyboard layout";
                console.warn(
                    root.switchError + ":",
                    (layoutSwitchError.text || layoutSwitchOutput.text).trim()
                        || "hyprctl exited with status " + exitCode
                );
            }
            root.refresh();
        }
    }
}
