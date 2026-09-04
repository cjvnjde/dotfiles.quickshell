import QtQuick
import Quickshell
import ".."

Rectangle {
    id: root

    width: languageText.implicitWidth + Theme.controlHorizontalPadding * 2
    height: parent.height
    radius: height / 2
    color: layoutMouse.containsMouse || layoutPopup.visible
        ? Theme.surface1 : Theme.surface0

    Text {
        id: languageText
        anchors.centerIn: parent
        text: KeyboardLayout.language
        color: Theme.text
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        id: layoutMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: layoutPopup.visible = !layoutPopup.visible
    }

    PopupWindow {
        id: layoutPopup
        readonly property int statusHeight:
            KeyboardLayout.switchError.length > 0 ? 32 : 0

        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        implicitWidth: 190
        implicitHeight: 12
            + statusHeight
            + Math.min(6, Math.max(1, KeyboardLayout.layouts.length)) * 40
        color: "transparent"
        grabFocus: true

        onVisibleChanged: {
            if (visible) {
                KeyboardLayout.refresh();
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.base
            border.color: Theme.surface1

            Text {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 8
                    leftMargin: 10
                    rightMargin: 10
                }
                visible: KeyboardLayout.switchError.length > 0
                text: KeyboardLayout.switchError
                color: Theme.red
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
            }

            Text {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: layoutPopup.statusHeight + 18
                }
                visible: KeyboardLayout.layouts.length === 0
                text: "No layouts configured"
                color: Theme.subtext0
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            ListView {
                id: layoutList
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: layoutPopup.statusHeight + 6
                    bottomMargin: 6
                    leftMargin: 6
                    rightMargin: 6
                }
                visible: KeyboardLayout.layouts.length > 0
                clip: true
                interactive: contentHeight > height
                model: KeyboardLayout.layouts

                delegate: Rectangle {
                    required property var modelData

                    readonly property bool active:
                        modelData.index === KeyboardLayout.activeIndex

                    width: ListView.view.width
                    height: 40
                    radius: Theme.radius
                    color: active
                        ? Theme.surface1
                        : layoutOptionMouse.containsMouse ? Theme.surface0 : "transparent"
                    opacity: KeyboardLayout.switching ? 0.65 : 1

                    Text {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 10
                        }
                        text: modelData.language
                        color: parent.active ? Theme.green : Theme.text
                        font.bold: true
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: 10
                        }
                        text: modelData.variant.length > 0
                            ? modelData.code.toUpperCase() + " · " + modelData.variant
                            : modelData.code.toUpperCase()
                        color: parent.active ? Theme.green : Theme.subtext0
                        elide: Text.ElideLeft
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }

                    MouseArea {
                        id: layoutOptionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !KeyboardLayout.switching
                        onClicked: {
                            KeyboardLayout.switchLayout(modelData.index);
                            layoutPopup.visible = false;
                        }
                    }
                }
            }
        }
    }
}
