import QtQuick
import Quickshell
import ".."

Rectangle {
    id: root

    readonly property var record: CodexUsage.record
    readonly property var limits: record ? record.limits || [] : []
    readonly property var days: record ? (record.recentDays || []).slice(-7) : []
    readonly property var models: record ? Object.keys(record.modelUsage || {}).sort((a, b) =>
        modelTotal(record.modelUsage[b]) - modelTotal(record.modelUsage[a])) : []
    readonly property real dailyMaximum: Math.max(1, ...days.map(day => Number(day.messageCount) || 0))
    readonly property real modelMaximum: models.length ? Math.max(1, modelTotal(record.modelUsage[models[0]])) : 1
    readonly property bool setupProblem: record !== null
        && (!!record.usageStatusText || limits.length === 0)

    function tokens(value) {
        if (value === undefined || value === null || !isFinite(Number(value))) return "—";
        const amount = Number(value);
        if (amount >= 1000000000) return (amount / 1000000000).toFixed(1) + "B";
        if (amount >= 1000000) return (amount / 1000000).toFixed(1) + "M";
        if (amount >= 1000) return (amount / 1000).toFixed(1) + "k";
        return Math.round(amount).toString();
    }

    function count(value) {
        return value === undefined || value === null ? "—" : Number(value).toLocaleString(Qt.locale(), "f", 0);
    }

    function modelTotal(usage) {
        return Number(usage.inputTokens || 0) + Number(usage.outputTokens || 0)
            + Number(usage.cacheReadInputTokens || 0) + Number(usage.cacheCreationInputTokens || 0);
    }

    function resetText(value) {
        const reset = new Date(value).getTime();
        if (!value || !isFinite(reset)) return "Reset time unavailable";
        const minutes = Math.ceil((reset - clock.date.getTime()) / 60000);
        if (minutes <= 0) return "Reset due";
        const days = Math.floor(minutes / 1440);
        const hours = Math.floor((minutes % 1440) / 60);
        return "Resets in " + (days ? days + "d " : "")
            + (hours ? hours + "h " : "") + (days ? "" : minutes % 60 + "m");
    }

    visible: CodexUsage.available
    width: visible ? pillIcon.implicitWidth + Theme.controlHorizontalPadding * 2 : 0
    height: parent.height
    radius: height / 2
    color: pillMouse.containsMouse || usagePopup.visible ? Theme.surface1 : Theme.surface0
    onVisibleChanged: if (!visible) usagePopup.visible = false

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    component UsageText: Text {
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        textFormat: Text.PlainText
    }

    component SectionLabel: UsageText {
        color: Theme.overlay0
        font.pixelSize: Theme.fontSize - 2
        font.capitalization: Font.AllUppercase
    }

    component Divider: Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }

    component UsageTooltip: PopupWindow {
        id: tooltipWindow
        property string text: ""
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        implicitWidth: tooltip.implicitWidth + 20
        implicitHeight: tooltip.implicitHeight + 16
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.base
            border.color: Theme.surface1

            UsageText {
                id: tooltip
                anchors.centerIn: parent
                text: tooltipWindow.text
                font.pixelSize: Theme.fontSize - 1
            }
        }
    }

    UsageText {
        id: pillIcon
        anchors.centerIn: parent
        text: "󱚣"
        font.pixelSize: Theme.fontSize + 2
        color: CodexUsage.error ? Theme.red : root.setupProblem ? Theme.yellow : Theme.blue
    }

    MouseArea {
        id: pillMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: usagePopup.visible = !usagePopup.visible
    }

    PopupWindow {
        id: usagePopup
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        implicitWidth: Math.min(380, screen ? screen.width - 16 : 380)
        implicitHeight: Math.min(details.implicitHeight + 28,
            screen ? screen.height - Theme.barHeight - 24 : 660)
        color: "transparent"
        grabFocus: true

        onVisibleChanged: {
            if (visible) {
                CodexUsage.refresh("limits");
                Qt.callLater(() => panel.forceActiveFocus());
            }
        }

        Rectangle {
            id: panel
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.base
            border.color: Theme.surface1
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) usagePopup.visible = false;
                else if (event.key === Qt.Key_R) CodexUsage.refresh("force");
                else return;
                event.accepted = true;
            }

            Flickable {
                id: content
                anchors.fill: parent
                anchors.margins: 14
                contentWidth: width
                contentHeight: details.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    id: details
                    width: content.width
                    spacing: 14

                    Column {
                        width: parent.width
                        spacing: 8
                        SectionLabel { text: "Limits" }

                        UsageText {
                            width: parent.width
                            visible: !!CodexUsage.error || !root.record || root.setupProblem
                            text: CodexUsage.error || (!root.record
                                ? (CodexUsage.refreshing ? "Loading…" : "Usage unavailable · r to refresh")
                                : root.record.usageStatusText || "Limits unavailable")
                            color: CodexUsage.error ? Theme.red : Theme.subtext0
                            wrapMode: Text.Wrap

                            MouseArea {
                                id: statusMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                            UsageTooltip {
                                anchor.item: statusMouse
                                visible: statusMouse.containsMouse && !!text && usagePopup.visible
                                text: root.record ? root.record.authHelpText || "" : ""
                            }
                        }

                        Repeater {
                            model: root.limits
                            Column {
                                required property var modelData
                                width: details.width
                                spacing: 5

                                Item {
                                    width: parent.width
                                    height: 16
                                    UsageText { text: modelData.label }
                                    UsageText {
                                        anchors.right: parent.right
                                        text: Math.round(modelData.percent * 100) + "%"
                                        font.pixelSize: Theme.fontSize - 2
                                    }
                                }
                                Rectangle {
                                    width: parent.width
                                    height: 4
                                    radius: height / 2
                                    color: Theme.surface0
                                    Rectangle {
                                        width: parent.width * Math.max(0, Math.min(1, modelData.percent))
                                        height: parent.height
                                        radius: parent.radius
                                        color: modelData.percent >= 0.9 ? Theme.red
                                            : modelData.percent >= 0.75 ? Theme.yellow : Theme.lavender
                                    }
                                }
                                UsageText {
                                    text: root.resetText(modelData.resetsAt)
                                    color: Theme.overlay0
                                    font.pixelSize: Theme.fontSize - 2
                                }
                            }
                        }
                    }

                    Divider {}

                    Column {
                        width: parent.width
                        spacing: 4
                        SectionLabel { text: "Tokens by day" }
                        Repeater {
                            model: root.days
                            Item {
                                id: dayRow
                                required property var modelData
                                readonly property bool today: modelData.date === Qt.formatDate(clock.date, "yyyy-MM-dd")
                                width: details.width
                                height: 24

                                UsageText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: dayRow.today ? "Today" : Qt.formatDate(new Date(modelData.date + "T12:00:00"), "ddd")
                                    color: dayRow.today ? Theme.text : Theme.overlay0
                                    font.pixelSize: Theme.fontSize - 1
                                    font.bold: dayRow.today
                                }
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 60
                                    width: parent.width - 122
                                    height: 4
                                    radius: height / 2
                                    color: Theme.surface0
                                    Rectangle {
                                        width: parent.width * Number(modelData.messageCount) / root.dailyMaximum
                                        height: parent.height
                                        radius: parent.radius
                                        color: dayRow.today ? Theme.lavender : Theme.overlay0
                                    }
                                }
                                UsageText {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.tokens(modelData.messageCount)
                                    color: dayRow.today ? Theme.text : Theme.overlay0
                                    font.pixelSize: Theme.fontSize - 1
                                    font.bold: dayRow.today
                                }
                            }
                        }
                    }

                    Divider {}

                    Column {
                        width: parent.width
                        spacing: 6
                        SectionLabel { text: "Tokens by model" }
                        UsageText {
                            visible: root.models.length === 0
                            text: root.record ? "No recorded usage" : "—"
                            color: Theme.overlay0
                            font.pixelSize: Theme.fontSize - 1
                        }
                        Repeater {
                            model: root.models
                            Item {
                                id: modelRow
                                required property string modelData
                                readonly property var usage: root.record.modelUsage[modelData]
                                width: details.width
                                height: 26

                                Rectangle {
                                    width: parent.width * root.modelTotal(modelRow.usage) / root.modelMaximum
                                    height: parent.height
                                    radius: 3
                                    color: modelMouse.containsMouse ? Theme.surface1 : Theme.surface0
                                }
                                UsageText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - modelCount.width - 24
                                    text: modelRow.modelData
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.fontSize - 1
                                }
                                UsageText {
                                    id: modelCount
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.tokens(root.modelTotal(modelRow.usage))
                                    font.pixelSize: Theme.fontSize - 1
                                }
                                MouseArea {
                                    id: modelMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                                UsageTooltip {
                                    anchor.item: modelRow
                                    visible: modelMouse.containsMouse && usagePopup.visible
                                    text: "Input: " + root.count(modelRow.usage.inputTokens)
                                        + "\nOutput: " + root.count(modelRow.usage.outputTokens)
                                        + "\nCache read: " + root.count(modelRow.usage.cacheReadInputTokens)
                                        + "\nCache write: " + root.count(modelRow.usage.cacheCreationInputTokens)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
