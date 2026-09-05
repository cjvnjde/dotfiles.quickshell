import QtQuick
import QtQuick.Layouts
import "AiChatLogic.js" as AiChatLogic
import ".."

Item {

    required property var controller
    required property int index
    required property string role
    required property string body
    required property string messageStatus
    required property string errorText
    required property string itemId
    required property string turnId
    required property string activityTitle
    required property var attachments
    property bool answerCopied: false
    readonly property int attachmentCount: attachments
        && attachments.count !== undefined
            ? attachments.count
            : attachments && attachments.length
                ? attachments.length : 0
    readonly property bool answerCopyAvailable: role === "assistant"
        && messageStatus !== "streaming"
        && body.length > 0
        && AiChatLogic.isAssistantResponseTail(controller.messages, index)
    readonly property real topSpacing: index > 0 ? 24 : 0

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
    implicitHeight: messageBubble.implicitHeight + topSpacing

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
        color: role === "user" ? AiChatTheme.userBackground : "transparent"

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
                visible: role !== "assistant" && body.length > 0
                text: body
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: role === "notice" ? AiChatTheme.mutedText : AiChatTheme.text
                selectionColor: AiChatTheme.selection
                selectedTextColor: AiChatTheme.selectedText
                font.family: Theme.fontFamily
                font.pixelSize: 15
                readOnly: true
                selectByMouse: true
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? implicitHeight : 0
                visible: role === "assistant"
                    && messageStatus === "streaming"
                    && activityTitle.length > 0
                text: activityTitle
                color: AiChatTheme.mutedText
                opacity: 1
                font.family: Theme.fontFamily
                font.pixelSize: 11

                SequentialAnimation on opacity {
                    running: parent.visible
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.8
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
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
                            id: assistantMarkdown

                            property var linkRanges: []

                            function discoverLinkRanges() {
                                const ranges = [];
                                let activeHref = "";
                                let activeStart = -1;
                                for (let position = 0; position < length; position++) {
                                    const character = positionToRectangle(position);
                                    const href = String(linkAt(
                                        character.x + 2,
                                        character.y + character.height / 2
                                    ) || "");
                                    if (href === activeHref) {
                                        continue;
                                    }
                                    if (activeHref.length > 0) {
                                        ranges.push({
                                            href: activeHref,
                                            start: activeStart,
                                            end: position
                                        });
                                    }
                                    activeHref = href;
                                    activeStart = href.length > 0 ? position : -1;
                                }
                                if (activeHref.length > 0) {
                                    ranges.push({
                                        href: activeHref,
                                        start: activeStart,
                                        end: length
                                    });
                                }
                                linkRanges = ranges;
                            }

                            function styleLinks(hoveredHref) {
                                if (!visible) {
                                    linkRanges = [];
                                    return;
                                }
                                discoverLinkRanges();
                                for (const range of linkRanges) {
                                    linkStyling.selectionStart = range.start;
                                    linkStyling.selectionEnd = range.end;
                                    linkStyling.color = AiChatTheme.accent;
                                    const linkFont = linkStyling.font;
                                    linkFont.underline = range.href === hoveredHref;
                                    linkStyling.font = linkFont;
                                }
                            }

                            Layout.fillWidth: true
                            Layout.preferredHeight: visible
                                ? contentHeight : 0
                            visible: markdownBlock.kind === "markdown"
                                && markdownBlock.text.length > 0
                            text: AiChatLogic.safeAssistantMarkdown(
                                markdownBlock.text)
                            textFormat: Text.MarkdownText
                            wrapMode: Text.Wrap
                            color: AiChatTheme.text
                            selectionColor: AiChatTheme.selection
                            selectedTextColor: AiChatTheme.selectedText
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            readOnly: true
                            selectByMouse: true
                            onTextChanged: linkStyleTimer.restart()
                            onVisibleChanged: {
                                if (visible) {
                                    linkStyleTimer.restart();
                                }
                            }
                            onLinkHovered: link => styleLinks(String(link || ""))
                            onLinkActivated: link => controller.openLink(link)

                            TextSelection {
                                id: linkStyling
                                document: assistantMarkdown.textDocument
                            }

                            Connections {
                                target: AiChatTheme

                                function onAccentChanged() {
                                    linkStyleTimer.restart();
                                }
                            }

                            Timer {
                                id: linkStyleTimer
                                interval: 50
                                onTriggered: assistantMarkdown.styleLinks(
                                    assistantMarkdown.hoveredLink)
                            }
                        }

                        Rectangle {
                            id: codeBlock
                            property bool copied: false

                            Layout.fillWidth: true
                            Layout.preferredHeight: visible
                                ? codeLayout.implicitHeight + 20 : 0
                            visible: markdownBlock.kind === "code"
                            radius: 10
                            color: AiChatTheme.codeBackground
                            border.width: 1
                            border.color: AiChatTheme.border

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
                                    color: AiChatTheme.mutedText
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
                                    color: AiChatTheme.text
                                    selectionColor: AiChatTheme.selection
                                    selectedTextColor: AiChatTheme.selectedText
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
                                    ? AiChatTheme.hover : AiChatTheme.surface

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
                                            ? AiChatTheme.success : AiChatTheme.mutedText
                                    }

                                    Rectangle {
                                        y: 4
                                        width: 10
                                        height: 10
                                        radius: 1
                                        color: codeCopyButton.color
                                        border.width: 1
                                        border.color: codeBlock.copied
                                            ? AiChatTheme.success : AiChatTheme.mutedText
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
                visible: errorText.length > 0
                    || messageStatus === "sending"
                    || (role === "assistant"
                        && messageStatus !== "streaming"
                        && messageStatus !== "completed")
                text: errorText.length > 0 ? errorText
                    : messageStatus === "sending" ? "Sending…" : messageStatus
                color: messageStatus === "failed"
                    || errorText.length > 0
                        ? AiChatTheme.error : AiChatTheme.mutedText
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
            color: answerCopyMouse.containsMouse
                ? AiChatTheme.hover : AiChatTheme.surface

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
                    border.color: answerCopied ? AiChatTheme.success : AiChatTheme.mutedText
                }

                Rectangle {
                    y: 4
                    width: 10
                    height: 10
                    radius: 1
                    color: answerCopyButton.color
                    border.width: 1
                    border.color: answerCopied ? AiChatTheme.success : AiChatTheme.mutedText
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
