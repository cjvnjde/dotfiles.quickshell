import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Rectangle {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool available: sink !== null && sink.audio !== null
    readonly property real volume: available ? sink.audio.volume : 0
    readonly property bool muted: available && sink.audio.muted

    function setVolume(value) {
        if (!available) {
            return;
        }

        sink.audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleMuted() {
        if (available) {
            sink.audio.muted = !sink.audio.muted;
        }
    }

    width: soundRow.implicitWidth + Theme.controlHorizontalPadding * 2
    height: parent.height
    radius: height / 2
    color: soundMouse.containsMouse ? Theme.surface1 : Theme.surface0

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Row {
        id: soundRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: !root.available
                ? "󰖁"
                : root.muted || root.volume === 0 ? "󰝟" : root.volume < 0.5 ? "󰕿" : "󰕾"
            color: root.muted ? Theme.red : Theme.green
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.available ? Math.round(root.volume * 100) + "%" : "N/A"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    MouseArea {
        id: soundMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.toggleMuted();
                return;
            }

            volumePopup.visible = !volumePopup.visible;
        }
        onWheel: wheel => root.setVolume(root.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
    }

    PopupWindow {
        id: volumePopup

        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        width: 270
        height: 106
        color: "transparent"
        grabFocus: true

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.base
            border.color: Theme.surface1

            Text {
                anchors {
                    top: parent.top
                    left: parent.left
                    margins: 14
                }
                text: root.sink ? (root.sink.description || root.sink.name) : "No audio output"
                width: parent.width - 28
                color: Theme.text
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Rectangle {
                id: volumeTrack
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 14
                    rightMargin: 14
                }
                height: 8
                radius: height / 2
                color: Theme.surface1

                Rectangle {
                    width: parent.width * root.volume
                    height: parent.height
                    radius: height / 2
                    color: root.muted ? Theme.overlay0 : Theme.green
                }

                Rectangle {
                    x: Math.max(0, Math.min(parent.width - width, parent.width * root.volume - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    radius: width / 2
                    color: Theme.text
                }

                MouseArea {
                    anchors {
                        fill: parent
                        topMargin: -8
                        bottomMargin: -8
                    }

                    function updateVolume(mouseX) {
                        root.setVolume(mouseX / width);
                    }

                    onPressed: mouse => updateVolume(mouse.x)
                    onPositionChanged: mouse => {
                        if (pressed) {
                            updateVolume(mouse.x);
                        }
                    }
                }
            }

            Text {
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    margins: 14
                }
                text: root.muted ? "Unmute" : "Mute"
                color: root.muted ? Theme.red : Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: root.toggleMuted()
                }
            }

            Text {
                anchors {
                    bottom: parent.bottom
                    right: parent.right
                    margins: 14
                }
                text: Math.round(root.volume * 100) + "%"
                color: Theme.green
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }
}
