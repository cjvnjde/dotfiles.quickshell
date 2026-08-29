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
    readonly property real topSpacing: activityVisible && index > 0 ? 24 : 0
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

            TextEdit {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? contentHeight : 0
                visible: role === "assistant"
                    && messageStatus === "streaming"
                    && body.length > 0
                text: AiChatLogic.safeAssistantMarkdown(body)
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

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? implicitHeight : 0
                visible: role === "assistant"
                    && messageStatus !== "streaming"
                    && body.length > 0
                spacing: 10

                Repeater {
                    model: messageStatus === "streaming"
                        ? [] : AiChatLogic.markdownBlocks(body)

                    ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 0

                        TextEdit {
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible
                                ? contentHeight : 0
                            visible: modelData.kind === "markdown"
                                && modelData.text.length > 0
                            text: AiChatLogic.safeAssistantMarkdown(modelData.text)
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
                            visible: modelData.kind === "code"
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

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.language.length > 0
                                            ? modelData.language : "code"
                                        color: "#858585"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 26
                                        radius: 7
                                        color: codeCopyMouse.containsMouse
                                            ? "#343434" : "#242424"

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
                                                    ? Theme.green : "#b5b5b5"
                                            }

                                            Rectangle {
                                                y: 4
                                                width: 10
                                                height: 10
                                                radius: 1
                                                color: codeCopyMouse.containsMouse
                                                    ? "#343434" : "#242424"
                                                border.width: 1
                                                border.color: codeBlock.copied
                                                    ? Theme.green : "#b5b5b5"
                                            }
                                        }

                                        MouseArea {
                                            id: codeCopyMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (controller.copyText(modelData.text)) {
                                                    codeBlock.copied = true;
                                                    codeCopyReset.restart();
                                                }
                                            }
                                        }
                                    }
                                }

                                TextEdit {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: contentHeight
                                    text: modelData.text
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
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 28
                        radius: 8
                        color: answerCopyMouse.containsMouse
                            ? "#2d2d2d" : "transparent"

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
                                border.color: answerCopied
                                    ? Theme.green : "#9b9b9b"
                            }

                            Rectangle {
                                y: 4
                                width: 10
                                height: 10
                                radius: 1
                                color: answerCopyMouse.containsMouse
                                    ? "#2d2d2d" : "#171717"
                                border.width: 1
                                border.color: answerCopied
                                    ? Theme.green : "#9b9b9b"
                            }
                        }

                        MouseArea {
                            id: answerCopyMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (controller.copyText(body)) {
                                    answerCopied = true;
                                    answerCopyReset.restart();
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
    }
}
