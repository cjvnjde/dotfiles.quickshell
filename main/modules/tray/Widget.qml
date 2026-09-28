import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../components"
import "."
BarModule {
    id: root
    implicitWidth: row.implicitWidth
    Row {
        id: row
        height: parent.height
        Repeater {
            model: SystemTray.items
            Item {
                required property var modelData
                width: 30
                height: row.height
                Image {
                    anchors.centerIn: parent
                    width: 16; height: 16
                    source: modelData.icon
                    sourceSize: Qt.size(16, 16)
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: event => {
                        if (event.button === Qt.RightButton && modelData.hasMenu && root.bar) {
                            const pos = root.bar.contentItem.mapFromItem(mouse, 0, height);
                            modelData.display(root.bar, pos.x, pos.y);
                        } else modelData.activate();
                    }
                }
            }
        }
    }
}
