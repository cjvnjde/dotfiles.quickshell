import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

Rectangle {
    id: root

    required property var notification
    signal dismissAll()

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property color frameColor: critical ? Theme.peach : Theme.blue

    implicitHeight: Math.min(contentLayout.implicitHeight + 16, 300)
    radius: 4
    color: Theme.base
    border.color: frameColor
    border.width: 3
    clip: true

    RowLayout {
        id: contentLayout
        anchors {
            fill: parent
            margins: 8
        }
        spacing: 0

        Image {
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            Layout.rightMargin: visible ? 8 : 0
            visible: source.toString().length > 0
            source: notification.image || notification.appIcon
            sourceSize: Qt.size(48, 48)
            fillMode: Image.PreserveAspectFit
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: notification.summary
                color: Theme.text
                elide: Text.ElideMiddle
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.Bold
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: notification.body
                color: Theme.text
                elide: Text.ElideMiddle
                maximumLineCount: 12
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.dismissAll();
                return;
            }

            if (mouse.button === Qt.MiddleButton && notification.actions.length > 0) {
                notification.actions[0].invoke();
                if (notification.resident) {
                    notification.dismiss();
                }
                return;
            }

            notification.dismiss();
        }
    }

    Timer {
        interval: 10000
        running: !root.critical
        onTriggered: notification.expire()
    }
}
