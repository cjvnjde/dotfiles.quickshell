import QtQuick
import "../../components"
import "."
BarModule {
    id: root
    implicitWidth: control.width
    active: control.panelOpen
    CalendarControl { id: control; height: root.height; format: root.settings.format || "ddd  HH:mm"; color: "transparent" }
}
