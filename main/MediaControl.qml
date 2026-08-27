import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root

    readonly property var player: Mpris.players.values.find(candidate => candidate.isPlaying)
        || Mpris.players.values.find(candidate => candidate.trackTitle.length > 0)
        || Mpris.players.values[0]
        || null
    readonly property string title: player
        ? player.trackTitle || player.identity || "Unknown title"
        : ""
    readonly property string artist: player ? player.trackArtist : ""
    readonly property string barLabel: artist ? title + " — " + artist : title

    visible: player !== null
    width: visible ? Math.min(nowPlayingLabel.implicitWidth, 210) : 0
    height: parent.height

    onPlayerChanged: {
        if (player === null) {
            mediaPopup.visible = false;
        }
    }

    Text {
        id: nowPlayingLabel

        anchors.fill: parent
        text: root.barLabel
        color: mediaMouse.containsMouse ? Theme.blue : Theme.text
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        id: mediaMouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: mediaPopup.visible = !mediaPopup.visible
    }

    PopupWindow {
        id: mediaPopup

        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        width: 340
        height: 148
        color: "transparent"
        grabFocus: true

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.base
            border.color: Theme.surface1

            Rectangle {
                id: artworkFrame

                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                    margins: 12
                }
                width: height
                radius: Theme.radius
                color: Theme.surface0
                clip: true

                Image {
                    id: artwork

                    anchors.fill: parent
                    source: root.player ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: artwork.status !== Image.Ready
                    text: "󰎆"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 34
                }
            }

            Item {
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: artworkFrame.right
                    right: parent.right
                    topMargin: 12
                    bottomMargin: 10
                    leftMargin: 12
                    rightMargin: 12
                }

                Text {
                    id: titleLabel

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    height: 22
                    text: root.title
                    color: Theme.text
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                }

                Text {
                    anchors {
                        top: titleLabel.bottom
                        left: parent.left
                        right: parent.right
                    }
                    height: 20
                    text: root.artist || (root.player ? root.player.identity : "")
                    color: Theme.subtext0
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Row {
                    anchors {
                        bottom: parent.bottom
                        horizontalCenter: parent.horizontalCenter
                    }
                    spacing: 12

                    Rectangle {
                        width: 34
                        height: 34
                        anchors.verticalCenter: parent.verticalCenter
                        radius: width / 2
                        color: previousMouse.containsMouse ? Theme.surface1 : Theme.surface0
                        opacity: root.player && root.player.canGoPrevious ? 1 : 0.35

                        Text {
                            anchors.fill: parent
                            text: "󰒮"
                            color: Theme.lavender
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 5
                        }

                        MouseArea {
                            id: previousMouse

                            anchors.fill: parent
                            enabled: root.player !== null && root.player.canGoPrevious
                            hoverEnabled: true
                            onClicked: root.player.previous()
                        }
                    }

                    Rectangle {
                        width: 40
                        height: 40
                        anchors.verticalCenter: parent.verticalCenter
                        radius: width / 2
                        color: playMouse.containsMouse ? Theme.sky : Theme.blue
                        opacity: root.player && root.player.canTogglePlaying ? 1 : 0.35

                        Text {
                            anchors.fill: parent
                            text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
                            color: Theme.base
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 6
                        }

                        MouseArea {
                            id: playMouse

                            anchors.fill: parent
                            enabled: root.player !== null && root.player.canTogglePlaying
                            hoverEnabled: true
                            onClicked: root.player.togglePlaying()
                        }
                    }

                    Rectangle {
                        width: 34
                        height: 34
                        anchors.verticalCenter: parent.verticalCenter
                        radius: width / 2
                        color: nextMouse.containsMouse ? Theme.surface1 : Theme.surface0
                        opacity: root.player && root.player.canGoNext ? 1 : 0.35

                        Text {
                            anchors.fill: parent
                            text: "󰒭"
                            color: Theme.lavender
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 5
                        }

                        MouseArea {
                            id: nextMouse

                            anchors.fill: parent
                            enabled: root.player !== null && root.player.canGoNext
                            hoverEnabled: true
                            onClicked: root.player.next()
                        }
                    }
                }
            }
        }
    }
}
