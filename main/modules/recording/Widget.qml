import QtQuick
import "../../components"
import "."
import "../capture"
BarModule {
    active: CaptureService.recording
    implicitWidth: button.implicitWidth
    BarButton {
        id: button
        anchors.fill: parent
        active: CaptureService.recording
        text: CaptureService.recording ? "󰻃 " + CaptureService.elapsed : "󰻂"
        tooltip: CaptureService.recording ? "Stop and save recording" : "Record screen · click: region · right: this display"
        onClicked: mouseButton => CaptureService.toggleRecording(mouseButton === Qt.RightButton, bar ? bar.screen.name : "")
    }
}
