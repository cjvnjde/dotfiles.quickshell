pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: bar
    required property var modelData
    required property var privacy
    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property bool specialOpen: !!monitor?.lastIpcObject?.specialWorkspace?.name
    readonly property color base: "#1e1e2e"
    readonly property color surface: "#313244"
    readonly property color foreground: "#cdd6f4"
    readonly property color lavender: "#b4befe"
    readonly property string fontFamily: "FiraCode Nerd Font"
    property bool calendarOpen: false
    property bool audioOpen: false
    readonly property int volume: Math.round((privacy.sink?.audio?.volume ?? 0) * 100)
    readonly property string volumeIcon: privacy.muted ? "\uf466" : (volume > 50 ? "\uf028" : "\uf027")
    readonly property bool bluetoothConnected: Bluetooth.devices.values.some(device => device.connected)

    anchors { top: true; left: true; right: true }
    implicitHeight: 24
    color: "transparent"
    // Hyprland gaps provide the bar inset; only Quake consoles start at the edge.
    // Never change monitor reservations when a scratchpad or console is toggled.
    exclusiveZone: 0
    // Only change stacking, never geometry or the reserved area.
    // An explicitly opened calendar remains usable above application windows.
    WlrLayershell.layer: specialOpen && !calendarOpen && !audioOpen ? WlrLayer.Bottom : WlrLayer.Top
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

    Rectangle {
        id: workspaceIsland
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: workspaceRow.width + 4
        height: 20
        radius: 4
        color: bar.base

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
                    const active = bar.monitor?.activeWorkspace?.id;
                    if (active > 5) numbers.add(active);
                    return Array.from(numbers).sort((a, b) => a - b);
                }
                Rectangle {
                    id: workspace
                    required property int modelData
                    readonly property int number: modelData
                    readonly property bool active: bar.monitor?.activeWorkspace?.id === number
                    width: 20
                    height: 16
                    radius: 4
                    color: active ? bar.lavender : (workspaceMouse.containsMouse ? bar.surface : "transparent")
                    Text {
                        anchors.fill: parent
                        text: workspace.number
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: workspace.active ? bar.base : "#a6adc8"
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

    Row {
        id: rightIslands
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Rectangle {
            visible: statusRow.width > 0
            width: visible ? statusRow.width + 12 : 0
            height: 20
            radius: 6
            color: bar.base
            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 8
                Repeater {
                    model: [
                        { show: bar.bluetoothConnected, icon: "\uf294", label: "Bluetooth connected", tint: "#89b4fa" },
                        { show: bar.privacy.cameraActive, icon: "\uf030", label: "Camera in use", tint: "#a6e3a1" },
                        { show: bar.privacy.microphoneActive, icon: "\uf130", label: "Microphone in use", tint: "#a6e3a1" },
                        { show: bar.privacy.screenActive, icon: "\uf108", label: "Screen sharing / capture", tint: "#fab387" },
                        { show: bar.privacy.microphoneMuted, icon: "\uf131", label: "Microphone muted · Super+M", tint: "#f38ba8" },
                        { show: bar.privacy.muted, icon: "\uf466", label: "Speakers muted", tint: "#f9e2af" }
                    ]
                    Text {
                        id: badge
                        required property var modelData
                        visible: modelData.show
                        text: modelData.icon
                        color: modelData.tint
                        height: 20
                        verticalAlignment: Text.AlignVCenter
                        font { family: bar.fontFamily; pixelSize: 12 }
                        ToolTip.visible: badgeMouse.containsMouse
                        ToolTip.text: modelData.label
                        MouseArea {
                            id: badgeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
            }
        }

        Rectangle {
            id: audioIsland
            width: audioLabel.width + 16
            height: 20
            radius: 6
            color: bar.audioOpen || audioMouse.containsMouse ? bar.surface : bar.base
            Text {
                id: audioLabel
                anchors.centerIn: parent
                text: bar.volumeIcon + " " + (bar.privacy.sink ? bar.volume + "%" : "—")
                color: bar.privacy.muted ? "#f9e2af" : bar.foreground
                font { family: bar.fontFamily; pixelSize: 12 }
            }
            ToolTip.visible: audioMouse.containsMouse && !bar.audioOpen
            ToolTip.text: "Sound · Click for controls · Scroll for volume · Middle-click to mute"
            MouseArea {
                id: audioMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        if (bar.privacy.sink?.audio)
                            bar.privacy.sink.audio.muted = !bar.privacy.sink.audio.muted;
                    } else {
                        bar.calendarOpen = false;
                        bar.audioOpen = !bar.audioOpen;
                    }
                }
                onWheel: wheel => {
                    const delta = wheel.angleDelta.y || wheel.pixelDelta.y;
                    if (bar.privacy.sink?.audio && delta !== 0)
                        bar.privacy.sink.audio.volume = Math.max(0, Math.min(1,
                            bar.privacy.sink.audio.volume + (delta > 0 ? 0.05 : -0.05)));
                    wheel.accepted = true;
                }
            }
        }

        Rectangle {
            id: clockIsland
            width: clockLabel.width + 12
            height: 20
            radius: 6
            color: bar.calendarOpen || clockMouse.containsMouse ? bar.surface : bar.base
            Text {
                id: clockLabel
                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, "h:mm AP")
                color: bar.foreground
                font { family: bar.fontFamily; pixelSize: 12; bold: true }
            }
            MouseArea {
                id: clockMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    bar.audioOpen = false;
                    bar.calendarOpen = !bar.calendarOpen;
                }
            }
        }
    }

    AudioPopup {
        anchor.item: audioIsland
        anchor.rect.y: audioIsland.height + 4
        anchor.rect.x: audioIsland.width - width
        visible: bar.audioOpen
        onDismissed: bar.audioOpen = false
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    CalendarPopup {
        anchor.item: clockIsland
        anchor.rect.y: clockIsland.height + 4
        anchor.rect.x: clockIsland.width - width
        visible: bar.calendarOpen
        today: clock.date
        onDismissed: bar.calendarOpen = false
    }
}
