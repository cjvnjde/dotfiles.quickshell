import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME")
        || Quickshell.env("HOME") + "/.config"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell-wallpaper"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    color: Theme.base

    Image {
        anchors.fill: parent
        source: SystemTheme.colorScheme.length === 0 ? ""
            : "file://" + root.configHome + "/hypr/assets/"
                + (SystemTheme.dark ? "bg_dark.jpg" : "bg_light.png")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        retainWhileLoading: true
    }
}
