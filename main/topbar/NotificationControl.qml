import QtQuick
import Quickshell
import ".."

Rectangle {
    id: root

    required property var controller
    required property var targetScreen

    width: notificationLabel.implicitWidth + Theme.controlHorizontalPadding * 2
    height: parent.height
    radius: height / 2
    color: notificationMouse.containsMouse ? Theme.surface1 : Theme.surface0
    Accessible.role: Accessible.Button
    Accessible.name: controller.activeCount + " active notifications, "
        + controller.historyCount + " in history"

    Text {
        id: notificationLabel

        anchors.centerIn: parent
        text: controller.activeCount > 0
            ? " " + controller.activeCount : ""
        color: controller.activeCount > 0 ? Theme.blue : Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 1
    }

    MouseArea {
        id: notificationMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.controller.toggleCenter(root.targetScreen)
    }

    PopupWindow {
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        visible: notificationMouse.containsMouse
        implicitWidth: tooltip.implicitWidth + 20
        implicitHeight: tooltip.implicitHeight + 16
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.base
            border.color: Theme.surface1

            Text {
                id: tooltip

                anchors.centerIn: parent
                text: root.controller.activeCount > 0
                    ? root.controller.activeCount + " active notifications"
                    : root.controller.historyCount > 0
                        ? "Open notification history" : "No notifications"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }
}
