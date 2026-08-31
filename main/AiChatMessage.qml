import QtQuick
import QtQuick.Layouts
import "AiChatLogic.js" as AiChatLogic

Item {

    required property var controller
    required property int index
    required property string role
    required property string body
    required property string messageStatus
    required property string errorText
    required property string itemId
    required property string turnId
    required property string activityType
    required property string activityTitle
    required property string activityOutput
    required property var attachments
    property bool activityExpanded: false
    property bool answerCopied: false
    readonly property int attachmentCount: attachments
        && attachments.count !== undefined
            ? attachments.count
            : attachments && attachments.length
                ? attachments.length : 0
    readonly property bool activityVisible: role !== "activity"
        || controller.activityMode === "detailed"
        || (controller.isGenerating && turnId === controller.currentTurnId
            && itemId === controller.latestActivityItemId)
    readonly property bool answerCopyAvailable: role === "assistant"
        && messageStatus !== "streaming"
        && body.length > 0
        && AiChatLogic.isAssistantResponseTail(controller.messages, index)
    readonly property real topSpacing: activityVisible && index > 0 ? 24 : 0

    function syncAssistantBlocks() {
        if (role !== "assistant" || body.length === 0) {
            assistantBlockModel.clear();
            return;
        }

        const blocks = AiChatLogic.markdownBlocks(body);
        for (let blockIndex = 0; blockIndex < blocks.length; blockIndex++) {
            const block = blocks[blockIndex];
            if (blockIndex >= assistantBlockModel.count) {
                assistantBlockModel.append(block);
                continue;
            }

            const currentBlock = assistantBlockModel.get(blockIndex);
            if (currentBlock.kind !== block.kind) {
                assistantBlockModel.setProperty(blockIndex, "kind", block.kind);
            }
            if (currentBlock.language !== block.language) {
                assistantBlockModel.setProperty(
                    blockIndex, "language", block.language);
            }
            if (currentBlock.text !== block.text) {
                assistantBlockModel.setProperty(blockIndex, "text", block.text);
            }
        }
        while (assistantBlockModel.count > blocks.length) {
            assistantBlockModel.remove(assistantBlockModel.count - 1);
        }
    }

    onBodyChanged: syncAssistantBlocks()
    onRoleChanged: syncAssistantBlocks()
    Component.onCompleted: syncAssistantBlocks()

    ListModel {
        id: assistantBlockModel
    }
    visible: activityVisible
    implicitHeight: activityVisible
        ? messageBubble.implicitHeight + topSpacing : 0

    TextMetrics {
        id: messageMetrics
        text: body
        font.family: Theme.fontFamily
        font.pixelSize: 15
    }

    Timer {
        id: answerCopyReset
        interval: 1400
        onTriggered: answerCopied = false
    }

    Rectangle {
        id: messageBubble
        y: topSpacing
        width: role === "user"
            ? Math.min(parent.width * 0.78,
                Math.max(attachmentCount > 0 ? 320 : 88,
                    messageMetrics.advanceWidth + 40))
            : parent.width
        implicitHeight: messageContent.implicitHeight
            + (role === "user" ? 28 : 0)
        anchors.right: role === "user" ? parent.right : undefined
        radius: role === "user" ? 18 : 0
        color: role === "user" ? "#2a2a2a" : "transparent"

        ColumnLayout {
            id: messageContent
            anchors {
                fill: parent
                margins: role === "user" ? 14 : 0
            }
            spacing: 10

            Repeater {
                model: attachments
                AiChatAttachment {
                    availableWidth: messageBubble.width - 24
                }
            }

            TextEdit {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? contentHeight : 0
                visible: role !== "assistant" && role !== "activity"
                    && body.length > 0
                text: body
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: role === "notice" ? "#b4b4b4" : "#eeeeee"
                selectionColor: "#515151"
                selectedTextColor: "#ffffff"
                font.family: Theme.fontFamily
                font.pixelSize: 15
                readOnly: true
                selectByMouse: true
            }

            Rectangle {
                id: activityCard
                readonly property string detailText: body
                    + (activityOutput.length > 0
                        ? (body.length > 0 ? "\n\n" : "") + activityOutput
                        : "")

                Layout.fillWidth: true
                Layout.preferredHeight: visible
                    ? activityLayout.implicitHeight + 24 : 0
                visible: role === "activity"
                radius: 12
                color: "#202020"
                border.width: 1
                border.color: "#343434"

                ColumnLayout {
                    id: activityLayout
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 12
                    }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 9
                            Layout.preferredHeight: 9
                            radius: 5
                            color: messageStatus === "failed"
                                || messageStatus === "declined"
                                    ? Theme.red
                                    : messageStatus === "completed"
                                        ? Theme.green : Theme.blue

                            SequentialAnimation on opacity {
                                running: activityCard.visible
                                    && messageStatus === "streaming"
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: 0.3
                                    duration: 520
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    to: 1
                                    duration: 520
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: activityTitle
                            color: "#e8e8e8"
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: AiChatLogic.activityStatusLabel(messageStatus)
                            color: messageStatus === "failed"
                                || messageStatus === "declined"
                                    ? Theme.red : "#858585"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        Text {
                            visible: activityCard.detailText.length > 0
                            text: "›"
                            rotation: activityExpanded ? 90 : 0
                            color: "#858585"
                            font.family: Theme.fontFamily
                            font.pixelSize: 18

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: activityCard.detailText.length > 0
                        text: activityCard.detailText
                        color: "#aaaaaa"
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: activityExpanded ? 1000 : 5
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        lineHeight: 1.15
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: activityCard.detailText.length > 0
                    cursorShape: enabled
                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: activityExpanded = !activityExpanded
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? implicitHeight : 0
                visible: role === "assistant" && body.length > 0
                spacing: 10

                Repeater {
                    model: assistantBlockModel

                    ColumnLayout {
                        id: markdownBlock
                        required property string kind
                        required property string language
                        required property string text
                        Layout.fillWidth: true
                        spacing: 0

                        TextEdit {
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible
                                ? contentHeight : 0
                            visible: markdownBlock.kind === "markdown"
                                && markdownBlock.text.length > 0
                            text: AiChatLogic.safeAssistantMarkdown(
                                markdownBlock.text)
                            textFormat: Text.MarkdownText
                            wrapMode: Text.Wrap
                            color: "#eeeeee"
                            selectionColor: "#515151"
                            selectedTextColor: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            readOnly: true
                            selectByMouse: true
                            onLinkActivated: link => controller.openLink(link)
                        }

                        Rectangle {
                            id: codeBlock
                            property bool copied: false

                            Layout.fillWidth: true
                            Layout.preferredHeight: visible
                                ? codeLayout.implicitHeight + 20 : 0
                            visible: markdownBlock.kind === "code"
                            radius: 10
                            color: "#111111"
                            border.width: 1
                            border.color: "#343434"

                            Timer {
                                id: codeCopyReset
                                interval: 1400
                                onTriggered: codeBlock.copied = false
                            }

                            ColumnLayout {
                                id: codeLayout
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    margins: 10
                                }
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    Layout.rightMargin: 38
                                    text: markdownBlock.language.length > 0
                                        ? markdownBlock.language : "code"
                                    color: "#858585"
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }

                                TextEdit {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: contentHeight
                                    text: markdownBlock.text
                                    textFormat: Text.PlainText
                                    wrapMode: TextEdit.WrapAnywhere
                                    color: "#d8d8d8"
                                    selectionColor: "#515151"
                                    selectedTextColor: "#ffffff"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    readOnly: true
                                    selectByMouse: true
                                }
                            }

                            HoverHandler {
                                id: codeHover
                            }

                            Rectangle {
                                id: codeCopyButton
                                anchors {
                                    top: parent.top
                                    right: parent.right
                                    margins: 7
                                }
                                width: 32
                                height: 28
                                opacity: codeHover.hovered
                                    || codeCopyMouse.containsMouse ? 1 : 0
                                z: 2
                                radius: 8
                                color: codeCopyMouse.containsMouse
                                    ? "#2d2d2d" : "#1d1d1d"

                                Behavior on opacity {
                                    NumberAnimation { duration: 100 }
                                }

                                Item {
                                    anchors.centerIn: parent
                                    width: 15
                                    height: 15

                                    Rectangle {
                                        x: 4
                                        width: 10
                                        height: 10
                                        radius: 1
                                        color: "transparent"
                                        border.width: 1
                                        border.color: codeBlock.copied
                                            ? Theme.green : "#8b8b8b"
                                    }

                                    Rectangle {
                                        y: 4
                                        width: 10
                                        height: 10
                                        radius: 1
                                        color: codeCopyMouse.containsMouse
                                            ? "#2d2d2d" : "#1d1d1d"
                                        border.width: 1
                                        border.color: codeBlock.copied
                                            ? Theme.green : "#8b8b8b"
                                    }
                                }

                                MouseArea {
                                    id: codeCopyMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (controller.copyText(
                                                markdownBlock.text)) {
                                            codeBlock.copied = true;
                                            codeCopyReset.restart();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

            }

            Text {
                Layout.preferredHeight: visible ? implicitHeight : 0
                visible: role !== "activity"
                    && (messageStatus !== "completed"
                        || errorText.length > 0)
                text: errorText.length > 0 ? errorText
                    : messageStatus === "sending"
                        ? "Sending…"
                        : messageStatus === "streaming"
                            ? "Responding…" : messageStatus
                color: messageStatus === "failed"
                    || errorText.length > 0
                        ? Theme.red : "#777777"
                font.family: Theme.fontFamily
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }
        }

        HoverHandler {
            id: messageHover
            enabled: answerCopyAvailable
        }

        Rectangle {
            id: answerCopyButton
            anchors {
                right: parent.right
                bottom: parent.bottom
            }
            width: 32
            height: 28
            visible: answerCopyAvailable
            opacity: messageHover.hovered
                || answerCopyMouse.containsMouse ? 1 : 0
            z: 2
            radius: 8
            color: answerCopyMouse.containsMouse ? "#2d2d2d" : "#1d1d1d"

            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }

            Item {
                anchors.centerIn: parent
                width: 15
                height: 15

                Rectangle {
                    x: 4
                    width: 10
                    height: 10
                    radius: 1
                    color: "transparent"
                    border.width: 1
                    border.color: answerCopied ? Theme.green : "#8b8b8b"
                }

                Rectangle {
                    y: 4
                    width: 10
                    height: 10
                    radius: 1
                    color: answerCopyMouse.containsMouse ? "#2d2d2d" : "#1d1d1d"
                    border.width: 1
                    border.color: answerCopied ? Theme.green : "#8b8b8b"
                }
            }

            MouseArea {
                id: answerCopyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const response = AiChatLogic.assistantResponseBody(
                        controller.messages, index);
                    if (controller.copyText(response)) {
                        answerCopied = true;
                        answerCopyReset.restart();
                    }
                }
            }
        }
    }
}
