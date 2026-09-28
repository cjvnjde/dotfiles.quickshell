import QtQuick
import "../../components"
import "."
BarModule {
    id: root
    implicitWidth: control.width

    PrivacyIndicators { id: control; height: root.height;  }
}
