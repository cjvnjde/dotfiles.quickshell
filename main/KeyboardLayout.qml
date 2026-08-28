pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    property string language: "--"

    function setLayout(layout) {
        if (!layout) {
            return;
        }

        const normalized = layout.trim().toLowerCase();
        if (normalized.startsWith("english")) {
            language = "EN";
        } else if (normalized.startsWith("russian")) {
            language = "RU";
        } else {
            language = normalized.slice(0, 2).toUpperCase();
        }
    }

    function refresh() {
        if (!layoutQuery.running) {
            layoutQuery.running = true;
        }
    }

    Component.onCompleted: refresh()

    Connections {
        target: Hyprland

        function onConnected() {
            root.refresh();
        }

        function onRawEvent(event) {
            if (event.name === "activelayout") {
                root.setLayout(event.parse(2)[1]);
            }
        }
    }

    Process {
        id: layoutQuery
        command: ["hyprctl", "-j", "devices"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const devices = JSON.parse(text);
                    const keyboards = devices.keyboards || [];
                    const keyboard = keyboards.find(device => device.main) || keyboards[0];
                    if (keyboard) {
                        root.setLayout(keyboard.active_keymap);
                    }
                } catch (error) {
                    console.warn("Failed to read the current keyboard layout:", error);
                }
            }
        }
    }
}
