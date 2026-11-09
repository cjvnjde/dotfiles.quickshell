pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland

Rectangle {
    id: island
    required property var screen
    required property color base
    required property color surface
    required property color lavender
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property int inset: 2
    readonly property int cellRadius: 3

    width: Math.max(height, workspaceRow.width + 2 * inset)
    height: workspaceRow.height + 2 * inset
    radius: cellRadius + inset
    color: base

    Row {
        id: workspaceRow
        anchors.centerIn: parent
        spacing: 1
        Repeater {
            // Always show 1–5; add higher workspaces only while they exist.
            model: {
                const numbers = new Set([1, 2, 3, 4, 5]);
                for (const ws of Hyprland.workspaces.values) {
                    if (ws.id > 5) numbers.add(ws.id);
                }
                const active = island.monitor?.activeWorkspace?.id;
                if (active > 5) numbers.add(active);
                return Array.from(numbers).sort((a, b) => a - b);
            }
            Rectangle {
                id: workspace
                required property int modelData
                readonly property int number: modelData
                readonly property bool active: island.monitor?.activeWorkspace?.id === number
                width: Math.max(height, workspaceLabel.implicitWidth + 4)
                height: 16
                radius: island.cellRadius
                color: active ? island.lavender : (workspaceMouse.containsMouse ? island.surface : "transparent")
                Text {
                    id: workspaceLabel
                    anchors.fill: parent
                    text: workspace.number
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: workspace.active ? island.base : "#a6adc8"
                    // Fixed text boxes and native glyph metrics avoid fractional
                    // centering and the Nerd Font's extra vertical line padding.
                    font { family: "sans-serif"; pixelSize: 11; weight: Font.DemiBold }
                    renderType: Text.NativeRendering
                }
                MouseArea {
                    id: workspaceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Hyprland 0.57 uses Lua dispatch expressions (also creates empty workspaces).
                    onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspace.number + " })")
                }
            }
        }
    }
}
