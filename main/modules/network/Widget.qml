import QtQuick
import "../../components"
import "."
BarModule {
    id: root
    implicitWidth: control.width
    active: control.panelOpen
    NetworkControl { id: control; height: root.height; compact: root.settings.compact !== false; color: "transparent" }
}
