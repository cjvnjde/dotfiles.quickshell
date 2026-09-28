import QtQuick
import "../../components"
import "."
BarModule {
    id: root
    implicitWidth: control.width

    SoundControl { id: control; height: root.height; compact: root.settings.compact !== false; color: "transparent" }
}
