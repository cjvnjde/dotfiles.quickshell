import QtQuick
import "../../components"
import "."
BarModule {
    id: root
    implicitWidth: control.width

    KeyboardLayoutControl { id: control; height: root.height; color: "transparent" }
}
