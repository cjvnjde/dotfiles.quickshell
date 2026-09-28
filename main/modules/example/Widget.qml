import QtQuick
import Quickshell
import "../../components"
import "."
// Add {"id": "example", "settings": {"label": "Terminal"}} to bar.json.
BarModule {
    id: root
    implicitWidth: button.implicitWidth
    BarButton {
        id: button
        anchors.fill: parent
        text: ""
        tooltip: root.settings.label || "Terminal"
        onClicked: Quickshell.execDetached(["ghostty"])
    }
}
