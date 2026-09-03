import QtQuick
import ".."

Rectangle {
    id: root

    required property var controller
    readonly property bool backendReady: controller.connectionState === "ready"
        || controller.connectionState === "streaming"
    readonly property bool limitAvailable:
        controller.weeklyLimitRemainingPercent >= 0
    readonly property string statusLabel: {
        if (controller.connectionState === "error") {
            return "Error";
        }
        if (!backendReady) {
            return controller.connectionState === "initializing"
                ? "Connecting" : "Starting";
        }
        if (limitAvailable) {
            return controller.weeklyLimitRemainingPercent + "%";
        }
        return controller.weeklyLimitLoading ? "Loading" : "Ready";
    }
    readonly property color statusColor: {
        if (controller.connectionState === "error") {
            return Theme.red;
        }
        return backendReady ? Theme.green : Theme.yellow;
    }

    width: statusRow.implicitWidth + Theme.controlHorizontalPadding * 2
    height: parent.height
    radius: height / 2
    color: controlMouse.containsMouse ? Theme.surface1 : Theme.surface0

    Row {
        id: statusRow

        anchors.centerIn: parent
        spacing: 4

        Text {
            text: "󰚩"
            color: root.statusColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
        }

        Text {
            text: root.statusLabel
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    MouseArea {
        id: controlMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.controller.open()
    }
}
