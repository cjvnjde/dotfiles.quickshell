import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Variants {
    id: view

    required property var controller

    model: Quickshell.screens

    PanelWindow {
        id: chatWindow

        required property var modelData
        readonly property var monitor: Hyprland.monitorFor(modelData)
        readonly property bool focusedScreen: monitor !== null && monitor.focused

        screen: modelData
        visible: view.controller.shown
            && (focusedScreen || Quickshell.screens.length === 1)
        color: "transparent"
        exclusiveZone: 0
        aboveWindows: true

        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: {
            if (visible) {
                Qt.callLater(() => composerPanel.focusComposer());
            }
        }

        Shortcut {
            sequence: "Escape"
            onActivated: view.controller.close()
        }

        Connections {
            target: view.controller
            function onFocusComposer() {
                if (chatWindow.visible) {
                    Qt.callLater(() => composerPanel.focusComposer());
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: view.controller.close()
        }

        Rectangle {
            id: card

            anchors.centerIn: parent
            width: Math.min(AiConfig.chatWidth, parent.width - 48)
            height: view.controller.conversationStarted
                ? Math.min(AiConfig.chatMaxHeight, parent.height * 0.86)
                : Math.min(Math.max(164, composerPanel.implicitHeight),
                    parent.height - 32)
            radius: view.controller.conversationStarted ? 24 : 30
            color: "#171717"
            border.width: 1
            border.color: "#3d3d3d"
            clip: true

            Behavior on height {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: mouse => mouse.accepted = true
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? 56 : 0
                    visible: view.controller.conversationStarted

                    Rectangle {
                        width: 34
                        height: 34
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 20 }
                        radius: 17
                        color: closeMouse.containsMouse ? "#292929" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: "#969696"
                            font.family: Theme.fontFamily
                            font.pixelSize: 23
                            font.weight: Font.Light
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: view.controller.close()
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 144
                        text: view.controller.currentTitle
                        color: "#f2f2f2"
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                }

                ListView {
                    id: messageList

                    Layout.fillWidth: true
                    Layout.fillHeight: visible
                    Layout.preferredHeight: visible ? -1 : 0
                    Layout.leftMargin: 28
                    Layout.rightMargin: 28
                    Layout.topMargin: 12
                    Layout.bottomMargin: 24
                    visible: view.controller.conversationStarted
                    model: view.controller.messages
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    property bool followNewest: true

                    onContentHeightChanged: {
                        if (followNewest) {
                            Qt.callLater(() => {
                                if (followNewest) {
                                    positionViewAtEnd();
                                }
                            });
                        }
                    }
                    onHeightChanged: {
                        if (followNewest) {
                            Qt.callLater(() => {
                                if (followNewest) {
                                    positionViewAtEnd();
                                }
                            });
                        }
                    }
                    onMovementStarted: followNewest = false
                    onMovementEnded: followNewest = atYEnd

                    delegate: AiChatMessage {
                        width: messageList.width
                        controller: view.controller
                    }
                }

                AiChatComposer {
                    id: composerPanel
                    controller: view.controller
                }
            }
        }

        Connections {
            target: view.controller
            function onSubmissionAccepted() { composerPanel.clearDraft(); }
        }
    }
}
