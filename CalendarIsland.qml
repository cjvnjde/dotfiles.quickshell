pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Rectangle {
    id: island
    required property color base
    required property color surface
    required property color foreground
    required property string fontFamily
    property bool open: false
    signal opened()
    onOpenChanged: { if (open) opened(); }

    width: clockLabel.width + 12
    height: 20
    radius: 6
    color: open || clockMouse.containsMouse ? surface : base

    Text {
        id: clockLabel
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "h:mm AP")
        color: island.foreground
        font { family: island.fontFamily; pixelSize: 12; bold: true }
    }
    MouseArea {
        id: clockMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: island.open = !island.open
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    CalendarPopup {
        target: island
        visible: island.open
        today: clock.date
        onDismissed: island.open = false
    }
}
