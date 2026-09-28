import QtQuick
import "../../components"
import "."
BarModule {
    id: root
    implicitWidth: control.width

    ThemeControl { id: control; height: root.height; color: "transparent" }
}
