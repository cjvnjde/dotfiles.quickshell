import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: attachment

    required property string hostPath
    required property string attachmentKind
    required property string displayName
    required property int index
    property bool pending: false
    property real availableWidth: 300

    signal removeRequested()

    Layout.preferredWidth: pending
        ? (attachmentKind === "image" ? 108 : 220)
        : Math.min(300, availableWidth)
    Layout.preferredHeight: attachmentKind === "image"
            && (pending || hostPath.length > 0)
        ? (pending ? 68 : 150) : 48
    radius: pending ? 10 : 12
    color: pending ? "#1c1c1c" : "#202020"
    clip: true

    Image {
        anchors { fill: parent; margins: attachment.pending ? 3 : 0 }
        visible: attachment.attachmentKind === "image"
            && attachment.hostPath.length > 0
        source: visible ? "file://" + attachment.hostPath : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: !attachment.pending
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: attachment.pending ? 38 : 10
            topMargin: attachment.pending ? 8 : 10
            bottomMargin: attachment.pending ? 8 : 10
        }
        spacing: attachment.pending ? 9 : 10
        visible: attachment.attachmentKind === "text"
            || (attachment.attachmentKind === "image"
                && attachment.hostPath.length === 0)

        Rectangle {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: 7
            color: "#343434"

            Text {
                anchors.centerIn: parent
                text: attachment.attachmentKind === "image" ? "IMG" : "TXT"
                color: "#cfcfcf"
                font.family: Theme.fontFamily
                font.pixelSize: 8
                font.weight: Font.DemiBold
            }
        }

        Text {
            Layout.fillWidth: true
            text: attachment.displayName
            color: "#dedede"
            elide: Text.ElideMiddle
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    Rectangle {
        width: 24
        height: 24
        anchors { top: parent.top; right: parent.right; margins: 4 }
        visible: attachment.pending
        radius: 12
        color: "#d8d8d8"

        Text {
            anchors.centerIn: parent
            text: "×"
            color: "#171717"
            font.pixelSize: 17
        }

        MouseArea {
            anchors.fill: parent
            onClicked: attachment.removeRequested()
        }
    }
}
