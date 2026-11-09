pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth

Rectangle {
    id: island
    required property var privacy
    required property color base
    required property string fontFamily
    readonly property bool bluetoothConnected: Bluetooth.devices.values.some(device => device.connected)

    visible: statusRow.width > 0
    width: visible ? statusRow.width + 12 : 0
    height: 20
    radius: 6
    color: base

    Row {
        id: statusRow
        anchors.centerIn: parent
        spacing: 8
        Repeater {
            model: [
                { show: island.bluetoothConnected, icon: "\uf294", label: "Bluetooth connected", tint: "#89b4fa" },
                { show: island.privacy.cameraActive, icon: "\uf030", label: "Camera in use", tint: "#a6e3a1" },
                { show: island.privacy.microphoneActive, icon: "\uf130", label: "Microphone in use", tint: "#a6e3a1" },
                { show: island.privacy.screenActive, icon: "\uf108", label: "Screen sharing / capture", tint: "#fab387" },
                { show: island.privacy.microphoneMuted, icon: "\uf131", label: "Microphone muted · Super+M", tint: "#f38ba8" },
                { show: island.privacy.muted, icon: "\uf466", label: "Speakers muted", tint: "#f9e2af" }
            ]
            Text {
                id: badge
                required property var modelData
                visible: modelData.show
                text: modelData.icon
                color: modelData.tint
                height: 20
                verticalAlignment: Text.AlignVCenter
                font { family: island.fontFamily; pixelSize: 12 }
                Accessible.name: modelData.label
                MouseArea {
                    id: badgeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                }
                BarTooltip {
                    target: badge
                    text: badge.modelData.label
                    shown: badgeMouse.containsMouse
                }
            }
        }
    }
}
