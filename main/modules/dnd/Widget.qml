import QtQuick
import "../../components"
import "."
BarModule {
    id: root
    active: !!bar && bar.notificationController.doNotDisturb
    implicitWidth: button.implicitWidth
    BarButton {
        id: button
        anchors.fill: parent
        text: "󰂛"
        active: root.active
        tooltip: root.active ? "Do Not Disturb is on · click to resume notifications" : "Silence notifications"
        onClicked: if (root.bar) root.bar.notificationController.setDoNotDisturb(!root.active)
    }
}
