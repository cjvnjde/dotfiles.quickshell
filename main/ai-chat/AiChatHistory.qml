import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: historyRoot

    required property var controller
    property string editingThreadId: ""
    property string confirmingDeleteThreadId: ""

    component SmallButton: Rectangle {
        property string label: ""
        property color labelColor: AiChatTheme.text
        signal clicked()

        implicitWidth: buttonLabel.implicitWidth + 16
        implicitHeight: 28
        radius: 8
        color: buttonMouse.containsMouse && enabled ? AiChatTheme.hover : AiChatTheme.raised
        opacity: enabled ? 1 : 0.38

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: parent.label
            color: parent.labelColor
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

    Connections {
        target: historyRoot.controller

        function onThreadRenameSucceeded(threadId) {
            if (historyRoot.editingThreadId === threadId) {
                historyRoot.editingThreadId = "";
            }
        }

        function onThreadDeleteSucceeded(threadId) {
            if (historyRoot.confirmingDeleteThreadId === threadId) {
                historyRoot.confirmingDeleteThreadId = "";
            }
            if (historyRoot.editingThreadId === threadId) {
                historyRoot.editingThreadId = "";
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Conversation history"
                color: AiChatTheme.text
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            SmallButton {
                label: "New chat"
                enabled: !historyRoot.controller.historyBusy
                onClicked: historyRoot.controller.newChat()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: historyRoot.controller.historyError.length > 0
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: historyRoot.controller.historyError
                color: AiChatTheme.error
                wrapMode: Text.Wrap
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            SmallButton {
                label: "Retry"
                enabled: !historyRoot.controller.historyBusy
                onClicked: historyRoot.controller.loadHistory(true)
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                anchors.centerIn: parent
                visible: historyRoot.controller.historyLoading
                    && historyRoot.controller.historyThreads.count === 0
                text: "Loading conversations…"
                color: AiChatTheme.mutedText
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }

            Text {
                anchors.centerIn: parent
                visible: !historyRoot.controller.historyLoading
                    && historyRoot.controller.historyThreads.count === 0
                    && historyRoot.controller.historyError.length === 0
                text: "No saved conversations"
                color: AiChatTheme.mutedText
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }

            ListView {
                id: historyList
                anchors.fill: parent
                visible: historyRoot.controller.historyThreads.count > 0
                model: historyRoot.controller.historyThreads
                spacing: 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: historyRow

                    required property string threadId
                    required property string title
                    required property string updatedText
                    required property string statusText
                    readonly property bool editing:
                        historyRoot.editingThreadId === threadId
                    readonly property bool confirmingDelete:
                        historyRoot.confirmingDeleteThreadId === threadId
                    readonly property bool operationTarget:
                        historyRoot.controller.historyTargetThreadId === threadId

                    width: historyList.width
                    height: editing ? 106 : 82
                    radius: 12
                    color: threadId === historyRoot.controller.currentThreadId
                        ? AiChatTheme.raised : AiChatTheme.surface
                    border.width: 1
                    border.color: threadId === historyRoot.controller.currentThreadId
                        ? AiChatTheme.accent : AiChatTheme.border

                    ColumnLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            TextInput {
                                id: nameInput
                                Layout.fillWidth: true
                                visible: historyRow.editing
                                text: historyRow.title
                                color: AiChatTheme.text
                                selectionColor: AiChatTheme.selection
                                selectedTextColor: AiChatTheme.selectedText
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                selectByMouse: true
                                onVisibleChanged: {
                                    if (visible) {
                                        text = historyRow.title;
                                        Qt.callLater(() => {
                                            forceActiveFocus();
                                            selectAll();
                                        });
                                    }
                                }
                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Return
                                            || event.key === Qt.Key_Enter) {
                                        historyRoot.controller.renameThread(
                                            historyRow.threadId, text);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Escape) {
                                        historyRoot.editingThreadId = "";
                                        event.accepted = true;
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: !historyRow.editing
                                text: historyRow.title
                                color: AiChatTheme.text
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }

                            Text {
                                text: historyRow.operationTarget
                                    ? historyRoot.controller.historyOperation + "…"
                                    : historyRow.statusText
                                color: historyRow.statusText === "Error"
                                    ? AiChatTheme.error : AiChatTheme.mutedText
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: historyRow.updatedText
                                color: AiChatTheme.mutedText
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }

                            SmallButton {
                                visible: historyRow.editing
                                label: "Save"
                                enabled: !historyRoot.controller.historyBusy
                                onClicked: historyRoot.controller.renameThread(
                                    historyRow.threadId, nameInput.text)
                            }

                            SmallButton {
                                visible: historyRow.editing
                                label: "Cancel"
                                enabled: !historyRoot.controller.historyBusy
                                onClicked: historyRoot.editingThreadId = ""
                            }

                            SmallButton {
                                visible: !historyRow.editing
                                    && !historyRow.confirmingDelete
                                label: historyRow.threadId
                                    === historyRoot.controller.currentThreadId
                                        ? "Current" : "Open"
                                enabled: !historyRoot.controller.historyBusy
                                    && historyRow.threadId
                                        !== historyRoot.controller.currentThreadId
                                onClicked: historyRoot.controller.resumeThread(
                                    historyRow.threadId)
                            }

                            SmallButton {
                                visible: !historyRow.editing
                                    && !historyRow.confirmingDelete
                                label: "Rename"
                                enabled: !historyRoot.controller.historyBusy
                                onClicked: {
                                    historyRoot.confirmingDeleteThreadId = "";
                                    historyRoot.editingThreadId = historyRow.threadId;
                                }
                            }

                            SmallButton {
                                visible: !historyRow.editing
                                label: historyRow.confirmingDelete
                                    ? "Confirm delete" : "Delete"
                                labelColor: AiChatTheme.error
                                enabled: !historyRoot.controller.historyBusy
                                onClicked: {
                                    if (historyRow.confirmingDelete) {
                                        historyRoot.controller.deleteThread(
                                            historyRow.threadId);
                                    } else {
                                        historyRoot.editingThreadId = "";
                                        historyRoot.confirmingDeleteThreadId
                                            = historyRow.threadId;
                                    }
                                }
                            }

                            SmallButton {
                                visible: historyRow.confirmingDelete
                                    && !historyRow.editing
                                label: "Cancel"
                                enabled: !historyRoot.controller.historyBusy
                                onClicked: historyRoot.confirmingDeleteThreadId = ""
                            }
                        }
                    }
                }

            }
        }

        SmallButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 4
            visible: historyRoot.controller.historyNextCursor.length > 0
                || historyRoot.controller.historyLoadingMore
            label: historyRoot.controller.historyLoadingMore
                ? "Loading…" : "Load more"
            enabled: !historyRoot.controller.historyLoadingMore
                && historyRoot.controller.historyOperation.length === 0
            onClicked: historyRoot.controller.loadHistory(false)
        }
    }
}
