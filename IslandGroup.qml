pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: group
    default property alias islands: contents.data
    required property color base
    required property color surface
    required property color foreground
    required property color lavender
    // Place a left-expanding group in a right-anchored layout, and vice versa.
    property int direction: Qt.LeftEdge
    property bool pinned: false
    property bool holdOpen: false
    property int spacing: 4
    readonly property bool expanded: holdOpen || pinned || (hover.hovered && !dismissed)
    property bool dismissed: false

    implicitWidth: toggle.width + reveal.width
    implicitHeight: 20
    width: implicitWidth
    height: implicitHeight

    function togglePinned(): void {
        pinned = !pinned;
        // Unpinning must close immediately, even with the pointer on the toggle.
        dismissed = !pinned;
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (!hovered) group.dismissed = false;
        }
    }

    Item {
        id: reveal
        x: group.direction === Qt.LeftEdge ? 0 : toggle.width
        width: group.expanded && contents.width > 0 ? contents.width + group.spacing : 0
        height: group.height
        clip: true
        enabled: group.expanded

        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
        }

        Row {
            id: contents
            x: group.direction === Qt.LeftEdge ? reveal.width - width - group.spacing : group.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: group.spacing
            // Keep the fade tied to the slide in both directions.
            opacity: width > 0 ? Math.min(1, reveal.width / (width + group.spacing)) : 0
        }
    }

    Rectangle {
        id: toggle
        x: group.direction === Qt.LeftEdge ? reveal.width : 0
        width: 20
        height: group.height
        radius: 6
        color: group.pinned ? group.lavender : toggleMouse.containsMouse ? group.surface : group.base
        Accessible.role: Accessible.Button
        Accessible.name: group.pinned ? "Collapse island group" : "Pin island group open"
        Accessible.checkable: true
        Accessible.checked: group.pinned
        Accessible.onPressAction: group.togglePinned()

        BarText {
            anchors.centerIn: parent
            text: (group.direction === Qt.LeftEdge) !== group.expanded ? "<" : ">"
            color: group.pinned ? group.base : group.foreground
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: group.togglePinned()
        }
    }
}
