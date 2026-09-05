import QtQuick
import ".."

Rectangle {
    id: actionButton

    property bool stopMode: false
    signal clicked()

    implicitWidth: 36
    implicitHeight: 36
    radius: 18
    color: stopMode ? AiChatTheme.actionHover
        : actionMouse.containsMouse && enabled
            ? AiChatTheme.actionHover : AiChatTheme.action
    opacity: enabled ? 1 : 0.38

    Canvas {
        readonly property color iconColor: AiChatTheme.actionText
        onIconColorChanged: requestPaint()
        anchors.fill: parent
        visible: !actionButton.stopMode
        onVisibleChanged: {
            if (visible) {
                requestPaint();
            }
        }
        onPaint: {
            const context = getContext("2d");
            context.clearRect(0, 0, width, height);
            context.strokeStyle = iconColor;
            context.lineWidth = 2;
            context.lineCap = "round";
            context.lineJoin = "round";
            context.beginPath();
            context.moveTo(11, 18);
            context.lineTo(18, 11);
            context.lineTo(25, 18);
            context.moveTo(18, 11);
            context.lineTo(18, 25);
            context.stroke();
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 10
        height: 10
        radius: 2
        visible: actionButton.stopMode
        color: AiChatTheme.actionText
    }

    MouseArea {
        id: actionMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: actionButton.enabled
        onClicked: actionButton.clicked()
    }
}
