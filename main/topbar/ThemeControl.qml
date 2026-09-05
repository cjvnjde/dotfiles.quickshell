import QtQuick
import Quickshell
import ".."

Rectangle {
    id: root

    width: themeText.implicitWidth + Theme.controlHorizontalPadding * 2
    height: parent.height
    radius: height / 2
    color: themeMouse.containsMouse ? Theme.surface1 : Theme.surface0
    Accessible.role: Accessible.Button
    Accessible.name: tooltip.text

    Text {
        id: themeText
        anchors.centerIn: parent
        text: SystemTheme.error.length > 0 ? ""
            : SystemTheme.colorScheme.length === 0 ? ""
            : SystemTheme.dark ? "" : ""
        color: SystemTheme.error.length > 0 ? Theme.red : Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 2
    }

    MouseArea {
        id: themeMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: SystemTheme.refresh()
        onClicked: SystemTheme.toggle()
    }

    PopupWindow {
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        visible: themeMouse.containsMouse
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
                text: SystemTheme.error.length > 0 ? SystemTheme.error
                    : "System appearance: switch to "
                        + (SystemTheme.dark ? "light" : "dark")
                color: SystemTheme.error.length > 0 ? Theme.red : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }
}
