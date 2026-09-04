import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import ".."

PanelWindow {
    id: root

    required property var notesController
    required property var aiController

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight
    color: "#40313244"

    readonly property var persistentWorkspaceIds: [1, 2, 3, 4, 5]
    readonly property var hyprlandMonitor: {
        Hyprland.monitors.values;
        return Hyprland.monitorFor(screen);
    }

    function workspaceById(workspaceId) {
        const workspaces = Hyprland.workspaces.values;
        for (let index = 0; index < workspaces.length; index++) {
            if (workspaces[index].id === workspaceId) {
                return workspaces[index];
            }
        }
        return null;
    }

    function workspaceIdsForMonitor() {
        const workspaceIds = persistentWorkspaceIds.slice();
        const workspaces = Hyprland.workspaces.values;
        for (let index = 0; index < workspaces.length; index++) {
            const workspace = workspaces[index];
            if (workspace.id > 0
                    && workspaceIds.indexOf(workspace.id) === -1
                    && workspace.monitor === hyprlandMonitor) {
                workspaceIds.push(workspace.id);
            }
        }
        workspaceIds.sort((left, right) => left - right);
        return workspaceIds;
    }

    Component.onCompleted: {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
    }

    Rectangle {
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            topMargin: Theme.barTopInset
            bottomMargin: Theme.barBottomInset
            leftMargin: Theme.barInset
        }
        width: workspaceRow.implicitWidth + Theme.barInset * 2
        radius: height / 2
        color: Theme.surface0

        Row {
            id: workspaceRow
            anchors.centerIn: parent
            spacing: 0

            Repeater {
                model: ScriptModel {
                    values: root.workspaceIdsForMonitor()
                }

                Rectangle {
                    required property int modelData

                    readonly property int workspaceId: modelData
                    readonly property var workspace: root.workspaceById(workspaceId)
                    readonly property bool active: root.hyprlandMonitor !== null
                        && root.hyprlandMonitor.activeWorkspace !== null
                        && root.hyprlandMonitor.activeWorkspace.id === workspaceId
                    readonly property bool urgent: workspace !== null
                        && workspace.urgent

                    width: 22
                    height: workspaceRow.parent.height
                    radius: height / 2
                    color: urgent
                        ? Theme.red
                        : workspaceMouse.containsMouse ? Theme.surface1 : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: String(parent.workspaceId)
                        color: parent.urgent
                            ? Theme.base
                            : parent.active ? Theme.sky : Theme.lavender
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    MouseArea {
                        id: workspaceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (parent.workspace !== null) {
                                parent.workspace.activate();
                            } else {
                                Hyprland.dispatch("workspace " + parent.workspaceId);
                            }
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width * 0.4)
        text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
        color: Theme.text
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    Row {
        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
            topMargin: Theme.barTopInset
            bottomMargin: Theme.barBottomInset
            rightMargin: Theme.barInset
        }
        spacing: 2

        PrivacyIndicators {}

        MediaControl {}

        SoundControl {}

        BluetoothControl {}

        NetworkControl {}

        LanguageControl {}

        AiChatControl {
            controller: root.aiController
        }

        NotesControl {
            controller: root.notesController
            screenName: root.screen.name
        }

        Rectangle {
            visible: SystemTray.items.values.length > 0
            width: visible ? trayRow.implicitWidth + Theme.controlHorizontalPadding * 2 : 0
            height: parent.height
            radius: height / 2
            color: Theme.surface0

            Row {
                id: trayRow
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: SystemTray.items

                    Item {
                        required property var modelData

                        width: 14
                        height: 20

                        Image {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            source: modelData.icon
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectFit
                        }

                        MouseArea {
                            id: trayMouse
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                                    const position = root.mapFromItem(trayMouse, mouse.x, mouse.y);
                                    modelData.display(root, position.x, position.y);
                                    return;
                                }

                                modelData.activate();
                            }
                        }
                    }
                }
            }
        }

        CalendarControl {}
    }
}
