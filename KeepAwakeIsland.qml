pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

Rectangle {
    id: island
    required property var keepAwake
    required property color base
    required property color surface
    required property color foreground
    required property color lavender
    required property string fontFamily

    width: Math.max(height, toggleIcon.width + height - toggleIcon.height)
    height: 20
    radius: 6
    color: island.keepAwake.enabled || toggleMouse.containsMouse ? surface : base

    IdleInhibitor {
        window: island.QsWindow.window
        enabled: island.keepAwake.enabled
    }

    BarIcon {
        id: toggleIcon
        anchors.centerIn: parent
        text: island.keepAwake.enabled ? "\uf0f4" : "\uf186"
        color: island.keepAwake.enabled ? island.lavender : island.foreground
        fontFamily: island.fontFamily
    }
    BarTooltip {
        target: island
        text: island.keepAwake.enabled
            ? "Keep awake on · Click to allow automatic sleep"
            : "Keep awake off · Click to prevent automatic sleep"
        shown: toggleMouse.containsMouse
    }
    MouseArea {
        id: toggleMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: island.keepAwake.enabled = !island.keepAwake.enabled
    }
}
