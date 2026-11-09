pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Rectangle {
    id: tray
    required property color base
    required property color surface

    visible: icons.width > 0
    width: visible ? icons.width + 8 : 0
    height: 20
    radius: 6
    color: base

    Row {
        id: icons
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: SystemTray.items

            Rectangle {
                id: button
                required property SystemTrayItem modelData
                width: 20
                height: 20
                radius: 4
                color: mouse.containsMouse || menu.visible ? tray.surface : "transparent"
                Accessible.name: modelData.title || modelData.id

                Image {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: button.modelData.icon
                    sourceSize: Qt.size(16, 16)
                    fillMode: Image.PreserveAspectFit
                }

                QsMenuAnchor {
                    id: menu
                    menu: button.modelData.menu
                    anchor.item: button
                    anchor.rect.y: button.height + 4
                }

                BarTooltip {
                    target: button
                    text: button.modelData.tooltipTitle || button.modelData.title || button.modelData.id
                    shown: mouse.containsMouse && !menu.visible
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: event => {
                        if (event.button === Qt.MiddleButton) {
                            button.modelData.secondaryActivate();
                        } else if (event.button === Qt.RightButton || button.modelData.onlyMenu) {
                            if (button.modelData.hasMenu) menu.open();
                        } else {
                            button.modelData.activate();
                        }
                    }
                    onWheel: event => {
                        const horizontal = event.angleDelta.y === 0;
                        const delta = horizontal ? event.angleDelta.x : event.angleDelta.y;
                        if (delta !== 0) button.modelData.scroll(delta, horizontal);
                        event.accepted = true;
                    }
                }
            }
        }
    }
}
