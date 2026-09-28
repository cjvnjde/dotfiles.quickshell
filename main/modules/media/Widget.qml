import QtQuick
import "../../components"
import "."
BarModule {
    id: root
    implicitWidth: control.width

    MediaControl { id: control; height: root.height;  }
}
