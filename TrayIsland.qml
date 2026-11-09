pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Rectangle {
    id: tray
    required property color base
    required property color surface
    readonly property int inset: 2
    readonly property int buttonRadius: 3

    visible: icons.width > 0
    width: visible ? Math.max(height, icons.width + 2 * inset) : 0
    height: 20
    radius: buttonRadius + inset
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
                width: height
                height: tray.height - 2 * tray.inset
                radius: tray.buttonRadius
                color: mouse.containsMouse || menu.visible ? tray.surface : "transparent"
                Accessible.name: modelData.title || modelData.id

                Image {
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    source: button.modelData.icon
                    sourceSize: Qt.size(width, height)
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
