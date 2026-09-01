import QtQuick
import ".."

Rectangle {
    id: card

    required property var controller
    required property string noteId
    property string pinScreenName: ""
    property bool dragEnabled: false
    property int minimumBodyHeight: 78

    readonly property int controllerRevision: controller.revision
    readonly property string noteBody: {
        card.controllerRevision;
        return controller.noteText(noteId);
    }
    readonly property bool notePinned: {
        card.controllerRevision;
        return controller.notePinned(noteId);
    }

    signal moveRequested()

    implicitHeight: header.height
        + Math.max(minimumBodyHeight, noteEditor.contentHeight + 4)
        + 24

    radius: 14
    color: Theme.mantle
    border.width: 1
    border.color: notePinned ? Theme.yellow : Theme.surface1
    clip: true

    component HeaderButton: Rectangle {
        required property string icon
        required property color iconColor
        signal clicked()

        width: 30
        height: 28
        radius: 8
        color: buttonMouse.containsMouse ? Theme.surface1 : "transparent"

        Text {
            anchors.centerIn: parent
            text: parent.icon
            color: parent.iconColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 3
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    Rectangle {
        id: header
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 38
        color: Theme.surface0

        Text {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 12
            }
            text: card.notePinned ? "PINNED" : "NOTE"
            color: card.notePinned ? Theme.yellow : Theme.subtext0
            font.bold: true
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
        }

        MouseArea {
            anchors.fill: parent
            enabled: card.dragEnabled
            hoverEnabled: enabled
            cursorShape: enabled ? Qt.SizeAllCursor : Qt.ArrowCursor

            onPressed: card.moveRequested()
        }

        Row {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 6
            }
            spacing: 2

            HeaderButton {
                icon: "󰐃"
                iconColor: card.notePinned ? Theme.yellow : Theme.subtext0
                onClicked: card.notePinned
                    ? card.controller.unpinNote(card.noteId)
                    : card.controller.pinNote(card.noteId, card.pinScreenName)
            }

            HeaderButton {
                icon: "󰆴"
                iconColor: Theme.red
                onClicked: card.controller.deleteNote(card.noteId)
            }
        }
    }

    Item {
        id: editorArea
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            margins: 12
        }
        height: Math.max(card.minimumBodyHeight, noteEditor.contentHeight + 4)

        TextEdit {
            id: noteEditor
            anchors.fill: parent
            text: card.noteBody
            color: Theme.text
            selectionColor: Theme.blue
            selectedTextColor: Theme.base
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            persistentSelection: true
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize

            onTextChanged: {
                if (text !== card.noteBody) {
                    card.controller.setNoteText(card.noteId, text);
                }
            }
            onActiveFocusChanged: {
                if (!activeFocus) {
                    card.controller.flushNotes();
                }
            }
        }

        Text {
            visible: noteEditor.text.length === 0 && !noteEditor.activeFocus
            text: "Write a note…"
            color: Theme.overlay0
            font: noteEditor.font
        }
    }

    Connections {
        target: card.controller

        function onNoteCreated(createdNoteId) {
            if (createdNoteId === card.noteId) {
                Qt.callLater(() => noteEditor.forceActiveFocus());
            }
        }
    }
}
