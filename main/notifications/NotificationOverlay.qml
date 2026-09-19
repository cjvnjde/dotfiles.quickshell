import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import ".."

Scope {
    id: root

    readonly property int activeCount: notificationServer.trackedNotifications.values.length
    readonly property int historyCount: historyEntries.length
    property bool centerOpen: false
    property bool expanded: false
    property bool showingHistory: false
    property var displayScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    property int historySequence: 0
    property var historyEntries: []
    Component.onCompleted: loadHistory()

    function loadHistory() {
        const contents = historyFile.text();
        if (contents.length === 0) {
            return;
        }

        try {
            const document = JSON.parse(contents);
            historyEntries = Array.isArray(document.entries) ? document.entries : [];
        } catch (error) {
            console.warn("Could not parse notification history:", error);
        }
    }

    function saveHistory() {
        historyFile.setText(JSON.stringify({ entries: historyEntries }, null, 2));
    }

    function visibleNotifications() {
        const notifications = notificationServer.trackedNotifications.values.slice().reverse();
        return expanded ? notifications : notifications.slice(0, 3);
    }

    function dismissAll() {
        const notifications = notificationServer.trackedNotifications.values.slice();
        notifications.forEach(notification => notification.dismiss());
        expanded = false;
    }

    function clearHistory() {
        historyEntries = [];
        saveHistory();
    }

    function recordNotification(notification) {
        if (notification.transient || notification.lastGeneration) {
            return;
        }

        const entries = historyEntries.slice();
        entries.unshift({
            historyId: Date.now() + "-" + notification.id + "-" + historySequence++,
            appName: String(notification.appName || ""),
            summary: String(notification.summary || ""),
            body: String(notification.body || ""),
            image: String(notification.image || notification.appIcon || ""),
            urgency: Number(notification.urgency),
            receivedAt: new Date().toISOString()
        });
        historyEntries = entries.slice(0, 100);
        saveHistory();
    }

    function toggleCenter(targetScreen) {
        if (centerOpen) {
            centerOpen = false;
            expanded = false;
            showingHistory = false;
            return;
        }

        if (targetScreen !== null && targetScreen !== undefined) {
            displayScreen = targetScreen;
        }
        centerOpen = true;
        expanded = true;
        showingHistory = activeCount === 0;
    }

    onActiveCountChanged: {
        if (activeCount === 0 && !centerOpen) {
            expanded = false;
            showingHistory = false;
        }
    }

    FileView {
        id: historyFile

        path: Quickshell.stateDir + "/notification-history.json"
        blockLoading: true
        printErrors: false
    }

    NotificationServer {
        id: notificationServer

        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;
            root.recordNotification(notification);
            if (!root.centerOpen) {
                root.expanded = false;
                root.showingHistory = false;
            }
        }
    }

    Variants {
        // Keep popups on one display while the bar remains visible on every display.
        model: root.displayScreen === null ? [] : [root.displayScreen]

        PanelWindow {
            id: notificationPanel

            required property var modelData
            readonly property real maximumListHeight: Math.max(
                120,
                screen.height - Theme.barHeight - Theme.notificationMargin
                    - panelHeader.implicitHeight - panelFooter.implicitHeight - 4
            )

            screen: modelData
            visible: root.centerOpen || root.activeCount > 0
            color: "transparent"
            implicitWidth: 400
            implicitHeight: panelHeader.implicitHeight
                + Math.min(
                    root.showingHistory
                        ? (root.historyCount > 0 ? historyList.contentHeight : 80)
                        : notificationList.contentHeight,
                    maximumListHeight
                )
                + panelFooter.implicitHeight + 4
            exclusiveZone: 0

            anchors {
                top: true
                right: true
            }

            margins {
                top: Theme.notificationMargin
                right: Theme.notificationMargin
            }
            ColumnLayout {
                anchors.fill: parent
                spacing: 2

                Rectangle {
                    id: panelHeader

                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Theme.radius
                    color: Theme.base
                    border.color: Theme.surface1

                    Text {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 10
                        }
                        text: root.showingHistory
                            ? "Notification history"
                            : root.activeCount + (root.activeCount === 1
                                ? " notification" : " notifications")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: 12
                        }
                        visible: root.centerOpen
                        text: "󰅖"
                        color: closeMouse.containsMouse ? Theme.red : Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 2

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.centerOpen = false;
                                root.expanded = false;
                                root.showingHistory = false;
                            }
                        }
                    }
                }

                ListView {
                    id: notificationList

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, notificationPanel.maximumListHeight)
                    visible: !root.showingHistory
                    clip: true
                    spacing: 2
                    model: ScriptModel {
                        values: root.visibleNotifications()
                    }

                    delegate: NotificationCard {
                        required property var modelData

                        width: ListView.view.width
                        notification: modelData
                        onDismissAll: root.dismissAll()
                    }
                }

                ListView {
                    id: historyList

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, notificationPanel.maximumListHeight)
                    visible: root.showingHistory && root.historyCount > 0
                    clip: true
                    spacing: 2
                    model: ScriptModel {
                        objectProp: "historyId"
                        values: root.historyEntries
                    }

                    delegate: NotificationHistoryCard {
                        required property var modelData

                        width: ListView.view.width
                        entry: modelData
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    visible: root.showingHistory && root.historyCount === 0
                    radius: Theme.radius
                    color: Theme.base
                    border.color: Theme.surface1

                    Text {
                        anchors.centerIn: parent
                        text: "No notification history"
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }

                Rectangle {
                    id: panelFooter

                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Theme.radius
                    color: Theme.base
                    border.color: Theme.surface1

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 8
                        }
                        spacing: 10

                        Text {
                            text: root.showingHistory
                                ? "Notifications (" + root.activeCount + ")"
                                : "History (" + root.historyCount + ")"
                            color: historyMouse.containsMouse ? Theme.blue : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.weight: Font.DemiBold

                            MouseArea {
                                id: historyMouse
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.centerOpen = true;
                                    root.showingHistory = !root.showingHistory;
                                    if (!root.showingHistory) {
                                        root.expanded = true;
                                    }
                                }
                            }
                        }

                        Text {
                            visible: !root.showingHistory && root.activeCount > 3
                            text: root.expanded ? "Show latest 3" : "Show all"
                            color: expandMouse.containsMouse ? Theme.blue : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.weight: Font.DemiBold

                            MouseArea {
                                id: expandMouse
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.centerOpen = true;
                                    root.expanded = !root.expanded;
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: root.showingHistory
                                ? root.historyCount > 0 : root.activeCount > 0
                            text: root.showingHistory ? "Clear history" : "Clear all"
                            color: clearMouse.containsMouse ? Theme.red : Theme.peach
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.weight: Font.DemiBold

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.showingHistory) {
                                        root.clearHistory();
                                    } else {
                                        root.dismissAll();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
