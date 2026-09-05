import QtQuick
import QtQuick.Layouts
import "AiChatLogic.js" as AiChatLogic
import ".."

Item {
    id: composerRoot

    required property var controller
    readonly property int contentBottomMargin: controller.conversationStarted
        ? (controller.pinned ? 8 : 20) : 4
    readonly property bool framed: controller.conversationStarted
        || controller.pinned

    function commandItems(draft) {
        return AiChatLogic.commandItems(draft, controller.availableModels,
            controller.selectedModel, controller.supportedEfforts,
            controller.selectedEffort, controller.presets, controller.pinned,
            controller.projects, controller.activeProjectId);
    }

    function focusComposer() {
        composer.forceActiveFocus();
    }

    function clearDraft() {
        composer.clear();
    }

    function completeMenuItem(item) {
        composer.text = AiChatLogic.replaceCommandDraft(composer.text, item.draft);
        composer.cursorPosition = composer.length;
        composer.forceActiveFocus();
    }

    function acceptMenuItem(item) {
        if (item.immediate) {
            composer.text = AiChatLogic.removeCommandDraft(composer.text);
            composer.cursorPosition = composer.length;
            controller.executeSlashCommand(item.draft);
            return;
        }

        completeMenuItem(item);
    }

    function submitComposer() {
        if (controller.isGenerating) {
            if (!controller.newChatPending) {
                controller.stop();
            }
            return;
        }
        if (controller.incompatibleActionRunning) {
            return;
        }

        const draft = composer.text.trim();
        const activeCommand = AiChatLogic.commandDraft(composer.text);
        if (activeCommand.length > 0) {
            const items = commandItems(activeCommand);
            for (const item of items) {
                if (item.immediate
                        && item.draft.trim() === activeCommand.trim()) {
                    acceptMenuItem(item);
                    return;
                }
            }
            if (commandPalette.visible && items.length > 0) {
                acceptMenuItem(items[Math.max(0, commandList.currentIndex)]);
                return;
            }
            if (draft === activeCommand.trim()) {
                if (controller.executeSlashCommand(activeCommand)) {
                    composer.clear();
                }
                return;
            }
        }
        if (controller.send(composer.text)) {
            composer.clear();
        }
    }

    Layout.fillWidth: true
    implicitHeight: composerStack.implicitHeight + contentBottomMargin
    Layout.maximumHeight: implicitHeight

    ColumnLayout {
        id: composerStack
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: composerRoot.framed ? 20 : 0
            rightMargin: composerRoot.framed ? 20 : 0
            bottomMargin: composerRoot.contentBottomMargin
        }
        spacing: 10

        Rectangle {
            id: commandPalette
            readonly property string draft: AiChatLogic.commandDraft(composer.text)

            Layout.fillWidth: true
            Layout.preferredHeight: visible
                ? Math.min(288, commandList.contentHeight + 12) : 0
            visible: draft.length > 0
                && composerRoot.commandItems(draft).length > 0
            radius: 29
            color: "#242424"
            border.width: 1
            border.color: "#3c3c3c"
            clip: true

            ListView {
                id: commandList
                anchors { fill: parent; margins: 6 }
                model: composerRoot.commandItems(commandPalette.draft)
                currentIndex: 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 46
                    radius: height / 2
                    color: index === commandList.currentIndex
                        || commandMouse.containsMouse ? "#353535" : "transparent"

                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        spacing: 14

                        Text {
                            text: modelData.label
                            color: "#f0f0f0"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.detail
                            color: "#8a8a8a"
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: commandMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: commandList.currentIndex = index
                        onClicked: composerRoot.acceptMenuItem(modelData)
                    }
                }
            }
        }

        Rectangle {
            id: composerFrame
            Layout.fillWidth: true
            Layout.preferredHeight: composerInner.implicitHeight
                + (controller.pinned ? 16 : 24)
            radius: composerRoot.framed ? 22 : 28
            color: composerRoot.framed ? "#272727" : "transparent"
            border.width: composerRoot.framed ? 1 : 0
            border.color: "#343434"

            ColumnLayout {
                id: composerInner
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: composerRoot.framed ? 12 : 20
                    rightMargin: composerRoot.framed ? 12 : 20
                    topMargin: controller.pinned ? 8 : 12
                }
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    visible: controller.pendingAttachments.count > 0
                    spacing: 8

                    Repeater {
                        model: controller.pendingAttachments
                        AiChatAttachment {
                            pending: true
                            onRemoveRequested: controller.removeAttachment(index)
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(
                        controller.conversationStarted ? 72 : 88,
                        Math.min(144, composer.contentHeight + 8))

                    Flickable {
                        id: composerViewport
                        anchors {
                            fill: parent
                            leftMargin: 2
                            rightMargin: 2
                            topMargin: 4
                            bottomMargin: 4
                        }
                        contentWidth: width
                        contentHeight: composer.contentHeight
                        clip: true

                        function ensureCursorVisible(cursorRectangle) {
                            if (height <= 0) {
                                return;
                            }

                            if (cursorRectangle.y < contentY) {
                                contentY = Math.max(0, cursorRectangle.y);
                            } else if (cursorRectangle.y
                                    + cursorRectangle.height
                                    > contentY + height) {
                                contentY = Math.min(
                                    Math.max(0, contentHeight - height),
                                    cursorRectangle.y
                                        + cursorRectangle.height - height);
                            }
                        }

                        TextEdit {
                            id: composer
                            width: parent.width
                            color: "#eeeeee"
                            selectionColor: "#515151"
                            selectedTextColor: "#ffffff"
                            wrapMode: TextEdit.Wrap
                            font.family: Theme.fontFamily
                            font.pixelSize: 15

                            onTextChanged: commandList.currentIndex = 0
                            onCursorRectangleChanged:
                                composerViewport.ensureCursorVisible(
                                    cursorRectangle)

                            Text {
                                visible: composer.text.length === 0
                                text: controller.conversationStarted
                                    ? "Message Codex" : "Ask Codex anything locally"
                                color: "#707070"
                                font: composer.font
                            }

                            Keys.onPressed: event => {
                                if (event.matches(StandardKey.Paste)) {
                                    controller.pasteClipboardImage();
                                    event.accepted = false;
                                    return;
                                }
                                if (event.key === Qt.Key_Escape) {
                                    controller.close();
                                    event.accepted = true;
                                } else if (commandPalette.visible
                                        && event.key === Qt.Key_Up) {
                                    commandList.currentIndex = Math.max(0,
                                        commandList.currentIndex - 1);
                                    event.accepted = true;
                                } else if (commandPalette.visible
                                        && event.key === Qt.Key_Down) {
                                    commandList.currentIndex = Math.min(
                                        commandList.count - 1,
                                        commandList.currentIndex + 1);
                                    event.accepted = true;
                                } else if (commandPalette.visible
                                        && event.key === Qt.Key_Tab) {
                                    const items = composerRoot.commandItems(
                                        commandPalette.draft);
                                    const index = Math.max(0,
                                        commandList.currentIndex);
                                    completeMenuItem(items[index]);
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Return
                                            || event.key === Qt.Key_Enter)
                                        && !(event.modifiers & Qt.ShiftModifier)) {
                                    composerRoot.submitComposer();
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    Layout.leftMargin: 2
                    Layout.rightMargin: 0
                    spacing: 12

                    RowLayout {
                        visible: controller.lastError.length === 0
                            && !controller.attachmentsBusy
                        spacing: 7

                        Rectangle {
                            width: 7
                            height: 7
                            radius: 3.5
                            color: controller.maintenanceStatusVisible
                                ? Theme.blue
                                : controller.codexAuthorized
                                    ? Theme.green : "#666666"
                        }

                        Text {
                            text: controller.maintenanceStatusVisible
                                ? controller.statusText
                                : controller.codexAuthorized
                                    ? "Authorized via sbx" : controller.statusText
                            color: controller.maintenanceStatusVisible
                                ? Theme.blue
                                : controller.codexAuthorized
                                    ? "#a8b8a4" : "#858585"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    Text {
                        Layout.fillWidth: visible
                        visible: controller.lastError.length > 0
                            || controller.attachmentsBusy
                        text: controller.attachmentsBusy
                            ? "Adding file…"
                            : controller.attachmentState === "failed"
                                ? controller.lastError
                                    + (controller.attachmentFailureStage === "copy"
                                        ? "  /retry  /discard" : "  /discard")
                                : controller.lastError
                        color: controller.lastError.length > 0
                            ? Theme.red : "#858585"
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    Rectangle {
                        Layout.preferredWidth: reconnectText.implicitWidth + 18
                        Layout.preferredHeight: 26
                        visible: controller.canReconnect
                        radius: 8
                        color: reconnectMouse.containsMouse
                            ? "#3a3a3a" : "#2c2c2c"

                        Text {
                            id: reconnectText
                            anchors.centerIn: parent
                            text: "Reconnect"
                            color: "#d8d8d8"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: reconnectMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: controller.reconnect()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: AiChatLogic.modelStatusText(
                            controller.selectedModelName,
                            controller.selectedEffort,
                            controller.activePresetName)
                        color: "#d8d8d8"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    AiChatActionButton {
                        stopMode: controller.isGenerating
                        enabled: controller.isGenerating
                            ? !controller.newChatPending
                            : (!controller.incompatibleActionRunning
                                && (composer.text.trim().length > 0
                                    || controller.pendingAttachments.count > 0))
                        onClicked: composerRoot.submitComposer()
                    }
                }
            }
        }
    }
}
