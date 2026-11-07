import QtQuick
import Quickshell
import Quickshell.Hyprland

PanelWindow {
    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 26
    color: "#1e1e2e"

    // Workspaces: click to switch
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Repeater {
            model: Hyprland.workspaces

            Text {
                id: ws
                required property var modelData
                text: modelData.name
                color: Hyprland.focusedWorkspace === modelData ? "#b4befe" : "#6c7086"
                font.pixelSize: 14

                MouseArea {
                    anchors.fill: parent
                    onClicked: ws.modelData.activate()
                }
            }
        }
    }

    // Clock
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
        color: "#cdd6f4"
        font.pixelSize: 14
    }
}
