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

                Item {
                    id: messageArea

                    Layout.fillWidth: true
                    Layout.fillHeight: visible
                    Layout.preferredHeight: visible ? -1 : 0
                    Layout.leftMargin: 28
                    Layout.rightMargin: 28
                    Layout.topMargin: 12
                    Layout.bottomMargin: 24
                    visible: view.controller.conversationStarted

                    Flickable {
                        id: messageList

                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: messageColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.VerticalFlick
                        flickDeceleration: 2800
                        maximumFlickVelocity: 6000
                        property bool followNewest: true
                        property real wheelVelocity: 0
                        property double wheelFrameTime: 0

                        function positionViewAtBeginning() {
                            contentY = 0;
                        }

                        function positionViewAtEnd() {
                            contentY = Math.max(0, contentHeight - height);
                        }

                        function stopWheelMomentum() {
                            wheelVelocity = 0;
                            wheelMomentum.stop();
                        }

                        function finishWheelMomentum() {
                            stopWheelMomentum();
                            followNewest = atYEnd;
                        }

                        function addWheelImpulse(steps) {
                            cancelFlick();
                            const impulse = -steps * 900;
                            if (wheelVelocity * impulse < 0) {
                                wheelVelocity = 0;
                            }
                            wheelVelocity = Math.max(-maximumFlickVelocity,
                                Math.min(maximumFlickVelocity,
                                    wheelVelocity + impulse));
                            followNewest = false;
                            if (!wheelMomentum.running) {
                                wheelFrameTime = Date.now();
                                wheelMomentum.start();
                            }
                        }

                        Timer {
                            id: wheelMomentum

                            interval: 16
                            repeat: true
                            onTriggered: {
                                const now = Date.now();
                                const elapsed = Math.min(0.032,
                                    Math.max(0.001,
                                        (now - messageList.wheelFrameTime)
                                            / 1000));
                                messageList.wheelFrameTime = now;

                                const maximumY = Math.max(0,
                                    messageList.contentHeight
                                        - messageList.height);
                                const nextY = Math.max(0,
                                    Math.min(maximumY,
                                        messageList.contentY
                                            + messageList.wheelVelocity
                                                * elapsed));
                                messageList.contentY = nextY;

                                const speedLoss =
                                    messageList.flickDeceleration * elapsed;
                                const atStart = nextY === 0
                                    && messageList.wheelVelocity < 0;
                                const atEnd = nextY === maximumY
                                    && messageList.wheelVelocity > 0;
                                if (Math.abs(messageList.wheelVelocity)
                                        <= speedLoss || atStart || atEnd) {
                                    messageList.finishWheelMomentum();
                                } else {
                                    messageList.wheelVelocity -= Math.sign(
                                        messageList.wheelVelocity) * speedLoss;
                                }
                            }
                        }

                        WheelHandler {
                            target: null
                            acceptedDevices: PointerDevice.Mouse
                            onWheel: event => {
                                const steps = event.angleDelta.y / 120;
                                if (steps === 0) {
                                    event.accepted = false;
                                    return;
                                }

                                messageList.addWheelImpulse(steps);
                                event.accepted = true;
                            }
                        }

                        onContentHeightChanged: {
                            if (followNewest) {
                                Qt.callLater(() => positionViewAtEnd());
                            }
                        }
                        onHeightChanged: {
                            if (followNewest) {
                                Qt.callLater(() => positionViewAtEnd());
                            }
                        }
                        onMovementStarted: {
                            stopWheelMomentum();
                            followNewest = false;
                        }
                        onMovementEnded: followNewest = atYEnd

                        Column {
                            id: messageColumn

                            width: messageList.width
                            spacing: 0

                            Repeater {
                                model: view.controller.messages

                                AiChatMessage {
                                    width: messageColumn.width
                                    controller: view.controller
                                }
                            }
                        }
                    }

                    Item {
                        id: scrollIndicator

                        readonly property real contentExtent:
                            messageList.contentHeight
                        readonly property bool dragging:
                            scrollIndicatorMouse.pressed

                        function setPosition(pointerY) {
                            const trackRange = height - scrollThumb.height;
                            if (trackRange <= 0) {
                                return;
                            }

                            const thumbY = Math.max(0, Math.min(trackRange,
                                pointerY - scrollIndicatorMouse.dragOffset));
                            const positionRatio = thumbY / trackRange;
                            if (positionRatio <= 0) {
                                messageList.positionViewAtBeginning();
                            } else if (positionRatio >= 1) {
                                messageList.positionViewAtEnd();
                            } else {
                                const contentRange = Math.max(0,
                                    contentExtent - messageList.height);
                                messageList.contentY =
                                    positionRatio * contentRange;
                            }
                        }

                        anchors {
                            top: parent.top
                            right: parent.right
                            bottom: parent.bottom
                            topMargin: 4
                            rightMargin: -22
                            bottomMargin: 4
                        }
                        width: 14
                        visible: contentExtent > messageList.height
                        z: 3


                        Rectangle {
                            id: scrollThumb

                            readonly property real viewportRatio: Math.min(1,
                                messageList.height
                                    / Math.max(messageList.height,
                                        scrollIndicator.contentExtent))
                            readonly property real contentRange: Math.max(0,
                                scrollIndicator.contentExtent
                                    - messageList.height)
                            readonly property real positionRatio:
                                messageList.atYBeginning ? 0
                                    : messageList.atYEnd ? 1
                                        : contentRange > 0
                                            ? Math.max(0, Math.min(1,
                                                messageList.contentY
                                                    / contentRange))
                                            : 0

                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 4
                            height: Math.max(
                                28, parent.height * viewportRatio)
                            y: (parent.height - height) * positionRatio
                            radius: width / 2
                            color: "#626262"
                            opacity: scrollIndicatorMouse.containsMouse
                                    || scrollIndicator.dragging
                                    || messageList.moving
                                    || wheelMomentum.running
                                ? 0.9 : 0.55

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        MouseArea {
                            id: scrollIndicatorMouse

                            property real dragOffset: 0

                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: Qt.SizeVerCursor
                            onPressed: mouse => {
                                messageList.stopWheelMomentum();
                                messageList.cancelFlick();
                                messageList.followNewest = false;
                                const overThumb = mouse.y >= scrollThumb.y
                                    && mouse.y <= scrollThumb.y
                                        + scrollThumb.height;
                                dragOffset = overThumb
                                    ? mouse.y - scrollThumb.y
                                    : scrollThumb.height / 2;
                                scrollIndicator.setPosition(mouse.y);
                            }
                            onPositionChanged: mouse => {
                                if (pressed) {
                                    scrollIndicator.setPosition(mouse.y);
                                }
                            }
                            onReleased: {
                                messageList.followNewest = messageList.atYEnd;
                            }
                            onCanceled: {
                                messageList.followNewest = messageList.atYEnd;
                            }
                        }
                    }

                    Rectangle {
                        id: scrollToBottomButton

                        readonly property bool available:
                            messageList.contentHeight > messageList.height
                            && !messageList.atYEnd

                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            bottom: parent.bottom
                            bottomMargin: 12
                        }
                        width: 40
                        height: 40
                        radius: 20
                        z: 2
                        opacity: available ? 1 : 0
                        scale: available ? 1 : 0.86
                        color: scrollToBottomMouse.containsMouse
                            ? "#3a3a3a" : "#292929"
                        border.width: 1
                        border.color: "#4a4a4a"

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "↓"
                            color: "#eeeeee"
                            font.family: Theme.fontFamily
                            font.pixelSize: 21
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: scrollToBottomMouse

                            anchors.fill: parent
                            enabled: scrollToBottomButton.available
                            hoverEnabled: true
                            cursorShape: enabled
                                ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                messageList.followNewest = true;
                                messageList.positionViewAtEnd();
                            }
                        }
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
