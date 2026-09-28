import QtQuick
import "../../components"
import "."
BarModule {
    id: root
    implicitWidth: control.width
    active: control.panelOpen
    CodexUsageControl { id: control; height: root.height; color: "transparent" }
}
