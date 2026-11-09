import QtQuick
import Quickshell

// Hover hint below a bar item. Qt ToolTips are drawn inside the 24px bar window
// and get clipped, so this uses its own popup surface.
PopupWindow {
    id: tip
    required property Item target
    property string text: ""
    property bool shown: false

    anchor.item: target
    anchor.rect.y: target.height + 4
    anchor.rect.x: target.width - width
    visible: shown && text.length > 0
    implicitWidth: label.implicitWidth + 12
    implicitHeight: label.implicitHeight + 8
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 3
        color: "#313244"
        border { width: 1; color: "#45475a" }
        Text {
            id: label
            anchors.centerIn: parent
            text: tip.text
            color: "#cdd6f4"
            font { family: "sans-serif"; pixelSize: 11 }
        }
    }
}
