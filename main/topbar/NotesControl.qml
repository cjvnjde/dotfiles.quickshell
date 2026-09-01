import QtQuick
import Quickshell
import "../notes"
import ".."

Rectangle {
    id: root

    required property var controller
    required property string screenName
    readonly property bool popupOpen: notesPopup.visible

    width: 30
    height: parent.height
    radius: height / 2
    color: notesMouse.containsMouse || popupOpen
        ? Theme.surface1 : Theme.surface0

    Text {
        anchors.centerIn: parent
        text: "󰎚"
        color: root.popupOpen ? Theme.yellow : Theme.lavender
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 3
    }

    Rectangle {
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 2
            rightMargin: 2
        }
        visible: root.controller.pinnedCount > 0
        width: 6
        height: 6
        radius: 3
        color: Theme.yellow
    }

    MouseArea {
        id: notesMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.controller.toggle(root.screenName)
    }

    PopupWindow {
        id: notesPopup

        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        implicitWidth: 660
        implicitHeight: Math.min(620, Math.max(220, notesPanel.contentHeight))
        color: "transparent"
        grabFocus: root.controller.popupGrabFocus
        visible: root.controller.shown
            && root.controller.popupScreenName === root.screenName

        onVisibleChanged: {
            if (!visible
                    && grabFocus
                    && root.controller.shown
                    && root.controller.popupScreenName === root.screenName) {
                root.controller.hide();
            }
        }

        Shortcut {
            sequence: "Escape"
            onActivated: root.controller.hide()
        }

        Rectangle {
            id: notesPanel

            readonly property real contentHeight: panelHeader.height
                + Math.max(146, noteFlow.height + 32)

            anchors.fill: parent
            radius: Theme.radius + 6
            color: Theme.base
            border.width: 1
            border.color: Theme.surface2
            clip: true

            Rectangle {
                id: panelHeader
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: 58
                color: Theme.mantle

                Text {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 18
                    }
                    text: "Notes"
                    color: Theme.text
                    font.bold: true
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 5
                }

                Text {
                    anchors {
                        right: addButton.left
                        verticalCenter: parent.verticalCenter
                        rightMargin: 12
                    }
                    text: root.controller.noteCount === 1
                        ? "1 note" : `${root.controller.noteCount} notes`
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }

                Rectangle {
                    id: addButton
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: 14
                    }
                    width: 38
                    height: 38
                    radius: 12
                    color: addMouse.containsMouse ? Theme.lavender : Theme.blue

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Theme.base
                        font.bold: true
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 8
                    }

                    MouseArea {
                        id: addMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.controller.createNote()
                    }
                }
            }

            Flickable {
                id: notesFlick
                anchors {
                    top: panelHeader.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: 16
                }
                contentWidth: width
                contentHeight: Math.max(height, noteFlow.height)
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Flow {
                    id: noteFlow
                    width: notesFlick.width
                    height: childrenRect.height
                    spacing: 12

                    Repeater {
                        model: root.controller.noteModel

                        Item {
                            id: noteDelegate

                            required property string noteId

                            width: noteFlow.width < 560
                                ? noteFlow.width
                                : (noteFlow.width - noteFlow.spacing) / 2
                            height: noteCard.implicitHeight

                            NoteCard {
                                id: noteCard
                                anchors.fill: parent
                                controller: root.controller
                                noteId: noteDelegate.noteId
                                pinScreenName: root.screenName
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: notesFlick
                visible: root.controller.noteCount === 0
                text: "No notes yet\nPress + to create one"
                color: Theme.subtext0
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.4
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
            }
        }
    }
}
