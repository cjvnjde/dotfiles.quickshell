import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../.."
import "../../components"
import "."

Item {
    id: root
    required property var screen
    implicitWidth: workspaceRow.implicitWidth
    property var persistentWorkspaceIds: [1, 2, 3, 4, 5]
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

    function workspaceHasToplevel(workspaceId) {
        const toplevels = Hyprland.toplevels.values;
        for (let index = 0; index < toplevels.length; index++) {
            const workspace = toplevels[index].workspace;
            if (workspace !== null && workspace.id === workspaceId) {
                return true;
            }
        }
        return false;
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
        Hyprland.refreshToplevels();
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "movewindowv2") {
                Hyprland.refreshToplevels();
            }
        }
    }

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
                readonly property bool occupied:
                    root.workspaceHasToplevel(workspaceId)

                width: 26
                height: root.height
                radius: 0
                color: "transparent"

                Text {
                    anchors.centerIn: parent
                    text: parent.active ? "󱓻" : String(parent.workspaceId === 10 ? 0 : parent.workspaceId)
                    color: parent.urgent
                        ? Theme.red
                        : workspaceMouse.containsMouse ? Theme.blue : parent.active ? Theme.text : parent.occupied ? Theme.text : Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Rectangle {
                    anchors {
                        top: parent.top
                        right: parent.right
                        topMargin: 3
                        rightMargin: 3
                    }
                    visible: parent.occupied && !parent.active
                    width: 4
                    height: 4
                    radius: width / 2
                    color: parent.urgent ? Theme.base : Theme.overlay0
                }

                MouseArea {
                    id: workspaceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (parent.workspace !== null) {
                            parent.workspace.activate();
                        } else if (Hyprland.usingLua) {
                            Hyprland.dispatch(
                                "hl.dsp.focus({ workspace = "
                                    + parent.workspaceId + " })");
                        } else {
                            Hyprland.dispatch("workspace " + parent.workspaceId);
                        }
                    }
                }
            }
        }
    }
}
