import QtQuick
import "../../components"
BarModule {
    id: root
    implicitWidth: button.implicitWidth
    BarButton {
        id: button
        anchors.fill: parent
        text: root.bar && root.bar.sectionRevealed(root.settings.section || "right") ? "›" : "‹"
        tooltip: "More controls · hover to reveal"
        onClicked: if (root.bar) root.bar.toggleSection(root.settings.section || "right")
    }
}
