import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."

Scope {
    id: view

    required property var controller
    property var activePopupContentItem: null

    function focusComposer() {
        if (controller.shown && !controller.historyVisible
                && card.parent !== null) {
            Qt.callLater(() => composerPanel.focusComposer());
        }
    }

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

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: chatWindow

            required property var modelData
            readonly property var monitor: Hyprland.monitorFor(modelData)
            readonly property bool focusedScreen: monitor !== null
                && monitor.focused

            screen: modelData
            visible: view.controller.shown && !view.controller.pinned
                && (focusedScreen || Quickshell.screens.length === 1)
            color: "transparent"
            exclusiveZone: 0
            aboveWindows: true

            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            onVisibleChanged: {
                if (visible) {
                    view.activePopupContentItem = contentItem;
                    view.focusComposer();
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: view.controller.historyVisible
                    ? view.controller.closeHistory() : view.controller.close()
            }

            MouseArea {
                anchors.fill: parent
                onClicked: view.controller.close()
            }
        }
    }

    FloatingWindow {
        id: pinnedWindow

        visible: view.controller.shown && view.controller.pinned
        implicitWidth: AiConfig.chatWidth
        implicitHeight: Math.min(AiConfig.chatMaxHeight, 860)
        minimumSize: Qt.size(480, 360)
        title: view.controller.activeProjectName + " · "
            + view.controller.currentTitle
        color: "#171717"

        onVisibleChanged: {
            if (visible) {
                view.focusComposer();
            }
        }
        onClosed: {
            if (view.controller.pinned) {
                view.controller.close();
            }
        }

        Shortcut {
            sequence: "Escape"
            onActivated: view.controller.historyVisible
                ? view.controller.closeHistory() : view.controller.close()
        }
    }

    Connections {
        target: view.controller
        function onFocusComposer() {
            view.focusComposer();
        }
    }

    Rectangle {
        id: card
        readonly property bool windowed: view.controller.pinned
        parent: windowed
            ? pinnedWindow.contentItem : view.activePopupContentItem
        visible: parent !== null

        anchors.centerIn: parent
        width: parent === null ? 0 : windowed
            ? parent.width
            : Math.min(AiConfig.chatWidth, parent.width - 48)
        readonly property bool expanded: view.controller.conversationStarted
            || view.controller.historyVisible
        height: parent === null ? 0 : windowed
            ? parent.height
            : expanded
                ? Math.min(AiConfig.chatMaxHeight, parent.height * 0.86)
                : Math.min(Math.max(216, composerPanel.implicitHeight + 52),
                    parent.height - 32)
        radius: windowed ? 0 : expanded ? 24 : 30
        color: "#171717"
        border.width: windowed ? 0 : 1
        border.color: "#3d3d3d"
        clip: true

        Behavior on height {
            enabled: !card.windowed
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
                id: header
                readonly property real controlInset: (height - 34) / 2
                Layout.fillWidth: true
                Layout.preferredHeight: card.windowed ? 40 : 52

                Rectangle {
                    width: 34
                    height: 34
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: header.controlInset
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

                Rectangle {
                    width: 34
                    height: 34
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: header.controlInset + 38
                    }
                    radius: 17
                    color: pinMouse.containsMouse || view.controller.pinned
                        ? "#292929" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: view.controller.pinned ? "󰐃" : "󰤱"
                        color: view.controller.pinned ? "#d5d5d5" : "#969696"
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                    }

                    MouseArea {
                        id: pinMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: view.controller.togglePinned()
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 260
                    text: view.controller.historyVisible
                        ? view.controller.activeProjectName + " conversations"
                        : view.controller.activeProjectName + " · "
                            + view.controller.currentTitle
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
                Layout.topMargin: card.windowed ? 4 : 12
                Layout.bottomMargin: card.windowed
                    ? 8 : view.controller.artifacts.count > 0 ? 12 : 24
                visible: view.controller.conversationStarted
                    && !view.controller.historyVisible
                model: view.controller.messages
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                property bool followNewest: true

                function boundedContentY(value) {
                    const minimum = originY;
                    const maximum = minimum
                        + Math.max(0, contentHeight - height);
                    return Math.max(minimum, Math.min(maximum, value));
                }

                function scrollWheel(event) {
                    const preciseDelta = event.pixelDelta.y;
                    const distance = preciseDelta !== 0
                        ? preciseDelta * 1.6
                        : event.angleDelta.y / 120 * 150;
                    if (distance === 0) {
                        return;
                    }

                    const direction = Math.sign(distance);
                    const previousDestination = wheelScroll.running
                            && wheelDirection === direction
                        ? wheelDestination : contentY;
                    wheelScroll.stop();
                    followNewest = false;
                    if (preciseDelta !== 0) {
                        contentY = boundedContentY(contentY - distance);
                        followNewest = atYEnd;
                    } else {
                        wheelDestination = boundedContentY(
                            previousDestination - distance);
                        wheelDirection = direction;
                        const remainingDistance = Math.abs(
                            wheelDestination - contentY);
                        if (remainingDistance < 0.5) {
                            contentY = wheelDestination;
                            wheelDirection = 0;
                            followNewest = atYEnd;
                        } else {
                            wheelScroll.from = contentY;
                            wheelScroll.to = wheelDestination;
                            wheelScroll.duration = Math.max(45, Math.min(
                                110, 110 * remainingDistance / 150));
                            wheelScroll.restart();
                        }
                    }
                    event.accepted = true;
                }

                property real wheelDestination: contentY
                property int wheelDirection: 0

                NumberAnimation {
                    id: wheelScroll
                    target: messageList
                    property: "contentY"
                    duration: 110
                    easing.type: Easing.OutCubic
                    onStopped: {
                        messageList.wheelDestination = messageList.contentY;
                        messageList.wheelDirection = 0;
                        messageList.followNewest = messageList.atYEnd;
                    }
                }

                WheelHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse
                        | PointerDevice.TouchPad
                    onWheel: event => messageList.scrollWheel(event)
                }

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
                Layout.bottomMargin: card.windowed ? 8 : 20
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

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !view.controller.conversationStarted
                    && !view.controller.historyVisible
            }

            AiChatComposer {
                id: composerPanel
                visible: !view.controller.historyVisible
                controller: view.controller
            }
        }
    }
}
