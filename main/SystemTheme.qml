pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    property string colorScheme: ""
    property string settingsError: ""
    property string appearanceError: ""
    property string appliedHyprlandMode: ""
    readonly property string error: settingsError || appearanceError
    readonly property bool dark: colorScheme === "prefer-dark"
    readonly property string mode: dark ? "dark" : "light"
    readonly property bool busy: schemeQuery.running || schemeSwitch.running

    function refresh() {
        if (!schemeQuery.running) {
            schemeQuery.running = true;
        }
    }

    function setMode(requestedMode) {
        if (requestedMode !== "light" && requestedMode !== "dark") {
            settingsError = "Unknown appearance mode: " + requestedMode;
            return false;
        }
        if (busy) {
            settingsError = "A system appearance change is already in progress.";
            return false;
        }

        settingsError = "";
        schemeSwitch.command = [
            "gsettings", "set", "org.gnome.desktop.interface", "color-scheme",
            requestedMode === "dark" ? "prefer-dark" : "prefer-light"
        ];
        schemeSwitch.running = true;
        return true;
    }

    function toggle() {
        setMode(dark ? "light" : "dark");
    }

    function updateScheme(value) {
        const scheme = String(value).trim().replace(/^'|'$/g, "");
        if (scheme === "default" || scheme === "prefer-light"
                || scheme === "prefer-dark") {
            colorScheme = scheme;
            applyHyprland();
        } else {
            settingsError = "Unknown system color scheme: " + scheme;
            console.warn(settingsError);
        }
    }

    function applyHyprland() {
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE").length === 0
                || colorScheme.length === 0 || hyprlandApply.running
                || appliedHyprlandMode === mode) {
            return;
        }

        hyprlandApply.appliedMode = mode;
        hyprlandApply.command = [
            "hyprctl", "eval",
            "require('modules.appearance').set_mode('" + mode + "')"
        ];
        hyprlandApply.running = true;
    }

    Component.onCompleted: refresh()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                root.appliedHyprlandMode = "";
                root.applyHyprland();
            }
        }
    }

    Process {
        id: schemeQuery
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        stdout: StdioCollector { id: queryOutput }
        stderr: StdioCollector { id: queryError }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.settingsError = "Could not read system color scheme: "
                    + queryError.text.trim();
                console.warn(root.error);
                return;
            }
            root.updateScheme(queryOutput.text);
        }
    }

    Process {
        id: schemeSwitch
        stderr: StdioCollector { id: switchError }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.settingsError = "Could not change system color scheme: "
                    + switchError.text.trim();
                console.warn(root.error);
            }
            root.refresh();
        }
    }

    Process {
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "color-scheme"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const prefix = "color-scheme:";
                if (data.startsWith(prefix)) {
                    root.updateScheme(data.slice(prefix.length));
                }
            }
        }
        stderr: StdioCollector { id: monitorError }
        onExited: function(exitCode) {
            root.settingsError = "System color scheme monitor stopped (" + exitCode
                + "): " + monitorError.text.trim();
            console.warn(root.error);
        }
    }

    Process {
        id: hyprlandApply
        property string appliedMode: ""
        stdout: StdioCollector { id: hyprlandOutput }
        stderr: StdioCollector { id: hyprlandError }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.appearanceError = "Could not apply Hyprland appearance: "
                    + (hyprlandError.text || hyprlandOutput.text).trim();
                console.warn(root.error);
            } else {
                root.appearanceError = "";
                root.appliedHyprlandMode = appliedMode;
            }
            if (appliedMode !== root.mode) {
                root.applyHyprland();
            }
        }
    }
}
