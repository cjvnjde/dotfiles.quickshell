import QtQuick
import "../../components"
import "."
import "../capture"
BarModule {
    implicitWidth: button.implicitWidth
    BarButton {
        id: button
        anchors.fill: parent
        text: "󰄀"
        tooltip: "Screenshot · click: region · right: full screen"
        onClicked: mouseButton => CaptureService.screenshot(mouseButton === Qt.RightButton)
    }
}
