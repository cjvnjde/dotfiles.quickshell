pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: island
    required property var sink
    required property color base
    required property color surface
    required property color foreground
    required property string fontFamily
    property bool open: false
    signal opened()
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property int volume: Math.round((sink?.audio?.volume ?? 0) * 100)
    readonly property string volumeIcon: muted ? "\uf466" : (volume > 50 ? "\uf028" : "\uf027")
    onOpenChanged: { if (open) opened(); }

    width: audioLabel.width + 16
    height: 20
    radius: 6
    color: open || audioMouse.containsMouse ? surface : base

    Text {
        id: audioLabel
        anchors.centerIn: parent
        text: island.volumeIcon + " " + (island.sink ? island.volume + "%" : "—")
        color: island.muted ? "#f9e2af" : island.foreground
        font { family: island.fontFamily; pixelSize: 12 }
    }
    BarTooltip {
        target: island
        text: "Sound · Click for controls · Scroll for volume · Middle-click to mute"
        shown: audioMouse.containsMouse && !island.open
    }
    MouseArea {
        id: audioMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                if (island.sink?.audio)
                    island.sink.audio.muted = !island.sink.audio.muted;
            } else {
                island.open = !island.open;
            }
        }
        onWheel: wheel => {
            const delta = wheel.angleDelta.y || wheel.pixelDelta.y;
            if (island.sink?.audio && delta !== 0)
                island.sink.audio.volume = Math.max(0, Math.min(1,
                    island.sink.audio.volume + (delta > 0 ? 0.05 : -0.05)));
            wheel.accepted = true;
        }
    }
    AudioPopup {
        target: island
        visible: island.open
        onDismissed: island.open = false
    }
}
