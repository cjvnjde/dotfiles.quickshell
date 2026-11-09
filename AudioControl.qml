pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Services.Pipewire

Column {
    id: control
    required property bool input
    readonly property var node: input ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink
    readonly property var devices: Pipewire.nodes.values.filter(n =>
        n.audio && !n.isStream && n.isSink !== input)
    readonly property bool available: !!node?.audio
    width: 240
    spacing: 0

    PwObjectTracker { objects: [control.node] }

    Row {
        spacing: 6
        Button {
            id: muteButton
            width: 24; height: 24
            enabled: control.available
            text: control.input
                ? (control.node?.audio?.muted ? "\uf131" : "\uf130")
                : (control.node?.audio?.muted ? "\uf466" : "\uf028")
            background: Rectangle {
                radius: 4
                color: muteButton.hovered ? "#313244" : "transparent"
            }
            contentItem: Text {
                text: muteButton.text
                color: control.node?.audio?.muted ? "#f38ba8" : "#b4befe"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font { family: "FiraCode Nerd Font"; pixelSize: 12 }
            }
            ToolTip.visible: hovered
            ToolTip.text: (control.node?.audio?.muted ? "Unmute " : "Mute ")
                + (control.input ? "microphone" : "output")
            Accessible.name: ToolTip.text
            onClicked: control.node.audio.muted = !control.node.audio.muted
        }
        Text {
            width: 78; height: 24
            text: control.input ? "Microphone" : "Output"
            color: "#cdd6f4"
            verticalAlignment: Text.AlignVCenter
            font { family: "sans-serif"; pixelSize: 11 }
        }
        ComboBox {
            id: devicePicker
            width: control.width - muteButton.width - 78 - 12
            height: 24
            enabled: control.devices.length > 0
            model: control.devices.map(n => n.description || n.nickname || n.name)
            currentIndex: control.devices.indexOf(control.node)
            displayText: currentIndex >= 0 ? currentText : "No device available"
            onActivated: index => {
                if (control.input) Pipewire.preferredDefaultAudioSource = control.devices[index];
                else Pipewire.preferredDefaultAudioSink = control.devices[index];
            }
            background: Rectangle {
                radius: 4
                color: devicePicker.hovered ? "#313244" : "transparent"
            }
            contentItem: Text {
                leftPadding: 2; rightPadding: 18
                text: devicePicker.displayText
                color: "#a6adc8"
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                font.pixelSize: 11
            }
            indicator: Text {
                x: devicePicker.width - width - 2
                anchors.verticalCenter: parent.verticalCenter
                text: "⌄"
                color: "#6c7086"
                font.pixelSize: 12
            }
            Accessible.name: control.input ? "Input device" : "Output device"
            ToolTip.visible: hovered
            ToolTip.text: displayText
        }
    }
    Row {
        spacing: 6
        Slider {
            id: volumeSlider
            width: control.width - 42
            height: 22
            enabled: control.available
            Accessible.name: control.input ? "Microphone volume" : "Output volume"
            from: 0; to: 1; stepSize: 0.01
            value: control.node?.audio?.volume ?? 0
            onMoved: {
                if (control.available) control.node.audio.volume = value;
            }
            background: Rectangle {
                x: volumeSlider.leftPadding
                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                width: volumeSlider.availableWidth; height: 3; radius: 2
                color: "#45475a"
                Rectangle {
                    width: volumeSlider.visualPosition * parent.width
                    height: parent.height; radius: 2
                    color: control.node?.audio?.muted ? "#6c7086" : "#b4befe"
                }
            }
            handle: Rectangle {
                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                width: 8; height: 8; radius: 4
                color: volumeSlider.pressed ? "#cdd6f4" : "#b4befe"
            }
        }
        Text {
            width: 36; height: 22
            text: control.available ? Math.round(control.node.audio.volume * 100) + "%" : "—"
            color: "#a6adc8"
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            font { family: "sans-serif"; pixelSize: 11 }
        }
    }
}
