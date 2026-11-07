import QtQuick
import Quickshell
import Quickshell.Wayland

// Desktop background: wallpaper.jpg, scaled to cover the screen
PanelWindow {
    required property var modelData
    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    WlrLayershell.layer: WlrLayer.Background
    exclusionMode: ExclusionMode.Ignore
    color: "#1e1e2e"

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("wallpaper.jpg")
        fillMode: Image.PreserveAspectCrop
    }
}
