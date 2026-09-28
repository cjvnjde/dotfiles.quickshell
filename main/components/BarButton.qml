import QtQuick
import Quickshell
import ".."
Rectangle {
    id: root
    property string text: ""
    property string tooltip: ""
    property bool active: false
    property color foreground: active ? Theme.red : Theme.text
    signal clicked(int button)
    implicitWidth: Math.max(30, label.implicitWidth + 16)
    implicitHeight: Theme.barHeight
    radius: Theme.buttonRadius
    color: mouse.containsMouse ? Theme.surface0 : "transparent"
    Accessible.role: Accessible.Button
    Accessible.name: tooltip
    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontTitle
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => root.clicked(event.button)
    }
    PopupWindow {
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 6
        visible: mouse.containsMouse && root.tooltip.length > 0
        implicitWidth: hint.implicitWidth + 22
        implicitHeight: hint.implicitHeight + 16
        color: "transparent"
        Rectangle {
            anchors.fill: parent
            color: Theme.base
            border.color: Theme.surface1
            radius: Theme.buttonRadius
            Text {
                id: hint
                anchors.centerIn: parent
                text: root.tooltip
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }
}
