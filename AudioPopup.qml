pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell

PopupWindow {
    id: popup
    required property Item target
    anchor.item: target
    anchor.rect.y: target.height + 4
    anchor.rect.x: target.width - width
    signal dismissed()
    implicitWidth: 264
    implicitHeight: content.implicitHeight + 24
    color: "transparent"
    grabFocus: true
    onVisibleChanged: { if (!visible) dismissed(); }

    Rectangle {
        anchors.fill: parent
        radius: 5
        color: "#1e1e2e"
        border { width: 1; color: "#313244" }
        focus: true
        Keys.onEscapePressed: popup.dismissed()

        Column {
            id: content
            anchors { top: parent.top; left: parent.left; margins: 12 }
            spacing: 10
            AudioControl { input: false }
            AudioControl { input: true }
            Button {
                id: mixerButton
                width: 240; height: 20
                text: "Mixer ↗"
                background: Rectangle {
                    radius: 4
                    color: "transparent"
                }
                contentItem: Text {
                    text: mixerButton.text
                    color: mixerButton.hovered ? "#b4befe" : "#6c7086"
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 11
                }
                onClicked: {
                    Quickshell.execDetached(["pavucontrol"]);
                    popup.dismissed();
                }
            }
        }
    }
}
