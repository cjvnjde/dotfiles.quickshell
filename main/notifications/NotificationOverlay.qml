import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import ".."

Scope {
    id: root

    function dismissAll() {
        const notifications = notificationServer.trackedNotifications.values.slice();
        notifications.forEach(notification => notification.dismiss());
    }

    NotificationServer {
        id: notificationServer

        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => notification.tracked = true
    }

    Variants {
        // Keep popups on one display while the bar remains visible on every display.
        model: Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : []

        PanelWindow {
            required property var modelData

            screen: modelData
            visible: notificationServer.trackedNotifications.values.length > 0
            color: "transparent"
            implicitWidth: 400
            implicitHeight: Math.min(
                notificationColumn.implicitHeight,
                screen.height - Theme.barHeight - Theme.notificationMargin
            )
            exclusiveZone: 0

            anchors {
                top: true
                right: true
            }

            margins {
                top: Theme.notificationMargin
                right: Theme.notificationMargin
            }

            ColumnLayout {
                id: notificationColumn
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                spacing: 2

                Repeater {
                    model: notificationServer.trackedNotifications

                    NotificationCard {
                        required property var modelData

                        Layout.fillWidth: true
                        notification: modelData
                        onDismissAll: root.dismissAll()
                    }
                }
            }
        }
    }
}
