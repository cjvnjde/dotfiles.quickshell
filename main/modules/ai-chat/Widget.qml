import QtQuick
import Quickshell
import "../../components"
import "."
BarModule {
    id: root
    available: Quickshell.env("QUICKSHELL_AI_AUTOSTART") !== "0"
    implicitWidth: control.item ? control.item.width : 0
    Loader {
        id: control
        active: root.available && !!root.bar
        height: root.height
        sourceComponent: AiChatControl { controller: root.bar.aiController }
    }
}
