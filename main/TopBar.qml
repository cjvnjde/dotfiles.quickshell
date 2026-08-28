import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

PanelWindow {
    id: root

    readonly property var hyprlandMonitor: Hyprland.monitorFor(screen)

    function refreshHyprlandState() {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
    }

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight
    color: "#40313244"

    Component.onCompleted: Qt.callLater(root.refreshHyprlandState)

    Connections {
        target: Hyprland

        function onConnected() {
            root.refreshHyprlandState();
        }
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
                    values: Hyprland.workspaces.values.filter(workspace =>
                        workspace.id > 0
                        && workspace.monitor === root.hyprlandMonitor
                    )
                }

                Rectangle {
                    required property var modelData

                    readonly property bool active: root.hyprlandMonitor !== null
                        && root.hyprlandMonitor.activeWorkspace !== null
                        && root.hyprlandMonitor.activeWorkspace.id === modelData.id

                    width: 22
                    height: workspaceRow.parent.height
                    radius: height / 2
                    color: modelData.urgent
                        ? Theme.red
                        : workspaceMouse.containsMouse ? Theme.surface1 : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: modelData.name
                        color: modelData.urgent
                            ? Theme.base
                            : parent.active ? Theme.sky : Theme.lavender
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    MouseArea {
                        id: workspaceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: modelData.activate()
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
