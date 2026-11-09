pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: bar
    required property var modelData
    required property var privacy
    required property var keepAwake
    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property bool specialOpen: !!monitor?.lastIpcObject?.specialWorkspace?.name
    readonly property color base: "#1e1e2e"
    readonly property color surface: "#313244"
    readonly property color foreground: "#cdd6f4"
    readonly property color lavender: "#b4befe"
    readonly property string fontFamily: "FiraCode Nerd Font"

    anchors { top: true; left: true; right: true }
    implicitHeight: 24
    color: "transparent"
    // Hyprland gaps provide the bar inset; only Quake consoles start at the edge.
    // Never change monitor reservations when a scratchpad or console is toggled.
    exclusiveZone: 0
    // Only change stacking, never geometry or the reserved area.
    // Explicitly opened island popups remain usable above application windows.
    WlrLayershell.layer: specialOpen && !calendarIsland.open && !audioIsland.open ? WlrLayer.Bottom : WlrLayer.Top
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name.startsWith("activespecial")) Hyprland.refreshMonitors();
        }
    }
    // Empty space between the islands does not intercept pointer input.
    mask: Region {
        item: workspaceIsland
        Region { item: rightIslands }
    }

    WorkspaceIsland {
        id: workspaceIsland
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        screen: bar.screen
        base: bar.base
        surface: bar.surface
        lavender: bar.lavender
    }

    Row {
        id: rightIslands
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        TrayIsland {
            base: bar.base
            surface: bar.surface
        }

        StatusIsland {
            privacy: bar.privacy
            base: bar.base
            fontFamily: bar.fontFamily
        }

        KeepAwakeIsland {
            keepAwake: bar.keepAwake
            base: bar.base
            surface: bar.surface
            foreground: bar.foreground
            lavender: bar.lavender
            fontFamily: bar.fontFamily
        }

        AudioIsland {
            id: audioIsland
            sink: bar.privacy.sink
            base: bar.base
            surface: bar.surface
            foreground: bar.foreground
            fontFamily: bar.fontFamily
            onOpened: calendarIsland.open = false
        }

        CalendarIsland {
            id: calendarIsland
            base: bar.base
            surface: bar.surface
            foreground: bar.foreground
            fontFamily: "sans-serif"
            onOpened: audioIsland.open = false
        }
    }

}
