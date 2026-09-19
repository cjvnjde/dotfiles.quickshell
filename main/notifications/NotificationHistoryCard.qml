import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import ".."

Rectangle {
    id: root

    required property var entry

    readonly property bool critical: Number(entry.urgency) === NotificationUrgency.Critical
    readonly property color frameColor: critical ? Theme.peach : Theme.surface1

    implicitHeight: Math.min(contentLayout.implicitHeight + 16, 240)
    radius: 4
    color: Theme.base
    border.color: frameColor
    border.width: critical ? 3 : 1
    clip: true

    ColumnLayout {
        id: contentLayout

        anchors {
            fill: parent
            margins: 8
        }
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Image {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                visible: source.toString().length > 0
                source: String(root.entry.image || "")
                sourceSize: Qt.size(36, 36)
                fillMode: Image.PreserveAspectFit
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: String(root.entry.appName || "")
                    color: Theme.subtext0
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }

                Text {
                    Layout.fillWidth: true
                    text: String(root.entry.summary || "")
                    color: Theme.text
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.Bold
                }
            }

            Text {
                text: Qt.formatDateTime(new Date(root.entry.receivedAt), "MMM d, hh:mm AP")
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: String(root.entry.body || "")
            color: Theme.text
            maximumLineCount: 8
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
