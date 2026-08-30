import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Variants {
    id: view

    required property var controller

    component HeaderButton: Rectangle {
        property string label: ""
        signal clicked()

        implicitWidth: buttonText.implicitWidth + 16
        implicitHeight: 30
        radius: 9
        color: buttonMouse.containsMouse && enabled ? "#303030" : "transparent"
        opacity: enabled ? 1 : 0.35

        Text {
            id: buttonText
            anchors.centerIn: parent
            text: parent.label
            color: "#b8b8b8"
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            enabled: parent.enabled
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }

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
            if (visible && !view.controller.historyVisible) {
                Qt.callLater(() => composerPanel.focusComposer());
            }
        }

        Shortcut {
            sequence: "Escape"
            onActivated: view.controller.historyVisible
                ? view.controller.closeHistory() : view.controller.close()
        }

        Connections {
            target: view.controller
            function onFocusComposer() {
                if (chatWindow.visible && !view.controller.historyVisible) {
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
            readonly property bool expanded: view.controller.conversationStarted
                || view.controller.historyVisible
            height: expanded
                ? Math.min(AiConfig.chatMaxHeight, parent.height * 0.86)
                : Math.min(Math.max(216, composerPanel.implicitHeight + 52),
                    parent.height - 32)
            radius: expanded ? 24 : 30
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
                    Layout.preferredHeight: 52

                    Rectangle {
                        width: 34
                        height: 34
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 16
                        }
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
                        width: parent.width - 260
                        text: view.controller.historyVisible
                            ? "Saved conversations"
                            : view.controller.currentTitle
                        color: "#f2f2f2"
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    Row {
                        anchors {
                            right: parent.right
                            rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 4

                        HeaderButton {
                            label: view.controller.historyVisible
                                ? "Chat" : "History"
                            enabled: view.controller.historyVisible
                                || view.controller.canOpenHistory
                            onClicked: view.controller.historyVisible
                                ? view.controller.closeHistory()
                                : view.controller.openHistory()
                        }

                        HeaderButton {
                            label: "Export"
                            enabled: view.controller.canExport
                                && !view.controller.historyVisible
                            onClicked: view.controller.exportConversation()
                        }
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
                    Layout.bottomMargin: view.controller.artifacts.count > 0
                        ? 12 : 24
                    visible: view.controller.conversationStarted
                        && !view.controller.historyVisible
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

                AiChatHistory {
                    Layout.fillWidth: true
                    Layout.fillHeight: visible
                    Layout.preferredHeight: visible ? -1 : 0
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.bottomMargin: 20
                    visible: view.controller.historyVisible
                    controller: view.controller
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? 84 : 0
                    Layout.leftMargin: 28
                    Layout.rightMargin: 28
                    visible: !view.controller.historyVisible
                        && view.controller.artifacts.count > 0

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6

                        Text {
                            text: "Generated files"
                            color: "#8f8f8f"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        ListView {
                            id: artifactList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: view.controller.artifacts
                            orientation: ListView.Horizontal
                            spacing: 8
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: AiChatArtifact {
                                controller: view.controller
                            }
                        }
                    }
                }

                AiChatComposer {
                    id: composerPanel
                    visible: !view.controller.historyVisible
                    controller: view.controller
                }
            }
        }

    }
}
