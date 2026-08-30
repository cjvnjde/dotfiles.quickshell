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

    ColumnLayout {
        id: contentLayout
        anchors {
            fill: parent
            margins: 8
        }
        spacing: 8

        RowLayout {
            id: notificationContent
            Layout.fillWidth: true
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

        RowLayout {
            Layout.alignment: Qt.AlignRight
            visible: notification.actions.length > 0
            spacing: 6

            Repeater {
                model: notification.actions

                Rectangle {
                    required property var modelData

                    implicitWidth: actionLabel.implicitWidth + 18
                    implicitHeight: 28
                    radius: 6
                    color: actionMouse.containsMouse ? "#313244" : "#1e1e2e"
                    border.width: 1
                    border.color: root.frameColor

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: modelData.text
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            const resident = root.notification.resident;
                            modelData.invoke();
                            if (resident) {
                                root.notification.dismiss();
                            }
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: notificationContent.implicitHeight + 16
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.dismissAll();
                return;
            }

            if (mouse.button === Qt.MiddleButton
                    && notification.actions.length > 0) {
                const resident = root.notification.resident;
                root.notification.actions[0].invoke();
                if (resident) {
                    root.notification.dismiss();
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
