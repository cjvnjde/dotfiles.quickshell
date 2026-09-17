import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import ".."

Rectangle {
    id: root

    readonly property var layouts: [
        { code: "EN", name: "English", keymap: "english" },
        { code: "RU", name: "Русский", keymap: "russian" }
    ]
    property int activeIndex: 0
    property string error: ""
    property int layoutSerial: 0

    function setFromKeymap(keymap) {
        const normalized = String(keymap).toLowerCase();
        for (let index = 0; index < layouts.length; index++) {
            if (normalized.includes(layouts[index].keymap)) {
                activeIndex = index;
                error = "";
                return;
            }
        }
    }

    function refreshLayout() {
        if (!layoutQuery.running && !layoutSwitch.running) {
            layoutQuery.requestSerial = layoutSerial;
            layoutQuery.running = true;
        }
    }

    function selectLayout(index) {
        if (index < 0 || index >= layouts.length || layoutSwitch.running) {
            return;
        }
        layoutSerial++;

        layoutSwitch.requestedIndex = index;
        layoutSwitch.command = [
            "hyprctl", "switchxkblayout", "all", String(index)
        ];
        layoutSwitch.running = true;
    }

    width: layoutLabel.implicitWidth + Theme.controlHorizontalPadding * 2
    height: parent.height
    radius: height / 2
    color: layoutMouse.containsMouse || layoutPopup.visible
        ? Theme.surface1 : Theme.surface0
    Accessible.role: Accessible.Button
    Accessible.name: "Keyboard layout: " + layouts[activeIndex].name

    Component.onCompleted: refreshLayout()

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "activelayout") {
                const fields = event.parse(2);
                root.setFromKeymap(fields[1]);
            } else if (event.name === "configreloaded") {
                root.refreshLayout();
            }
        }
    }

    Text {
        id: layoutLabel
        anchors.centerIn: parent
        text: root.layouts[root.activeIndex].code
        color: root.error.length > 0 ? Theme.red : Theme.text
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        textFormat: Text.PlainText
    }

    MouseArea {
        id: layoutMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            layoutPopup.visible = !layoutPopup.visible;
            if (layoutPopup.visible) {
                root.refreshLayout();
            }
        }
    }

    Process {
        id: layoutQuery
        property int requestSerial: -1
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector { id: layoutQueryOutput }
        stderr: StdioCollector { id: layoutQueryError }
        onExited: function(exitCode) {
            if (requestSerial !== root.layoutSerial) {
                Qt.callLater(() => root.refreshLayout());
                return;
            }
            if (exitCode !== 0) {
                root.error = "Could not read keyboard layout: "
                    + layoutQueryError.text.trim();
                return;
            }

            try {
                const keyboards = JSON.parse(layoutQueryOutput.text).keyboards || [];
                const keyboard = keyboards.find(candidate => candidate.main)
                    || keyboards[0];
                if (keyboard && keyboard.active_keymap) {
                    root.setFromKeymap(keyboard.active_keymap);
                }
            } catch (exception) {
                root.error = "Could not parse keyboard layout";
            }
        }
    }

    Process {
        id: layoutSwitch
        property int requestedIndex: -1
        stderr: StdioCollector { id: layoutSwitchError }
        onExited: function(exitCode) {
            if (exitCode === 0) {
                root.activeIndex = requestedIndex;
                root.error = "";
            } else {
                root.error = "Could not switch keyboard layout: "
                    + layoutSwitchError.text.trim();
            }
            Qt.callLater(() => root.refreshLayout());
        }
    }

    PopupWindow {
        id: layoutPopup

        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        implicitWidth: 220
        implicitHeight: layoutMenu.implicitHeight + 16
        color: "transparent"
        grabFocus: true
        onVisibleChanged: if (visible) Qt.callLater(() => panel.forceActiveFocus())

        Rectangle {
            id: panel
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.base
            border.color: Theme.surface1
            focus: true
            Keys.onEscapePressed: layoutPopup.visible = false

            Column {
                id: layoutMenu
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 8
                }
                spacing: 4

                Repeater {
                    model: root.layouts

                    Rectangle {
                        required property var modelData
                        required property int index

                        width: layoutMenu.width
                        height: 38
                        radius: Theme.radius
                        color: index === root.activeIndex
                            ? Theme.surface1
                            : optionMouse.containsMouse ? Theme.surface0 : "transparent"
                        Accessible.role: Accessible.Button
                        Accessible.name: "Select " + modelData.name + " keyboard layout"

                        Text {
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                                leftMargin: 10
                            }
                            text: modelData.name
                            color: index === root.activeIndex ? Theme.blue : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            textFormat: Text.PlainText
                        }

                        Text {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                rightMargin: 10
                            }
                            text: index === root.activeIndex ? "✓  " + modelData.code
                                : modelData.code
                            color: index === root.activeIndex ? Theme.blue : Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            textFormat: Text.PlainText
                        }

                        MouseArea {
                            id: optionMouse
                            anchors.fill: parent
                            enabled: !layoutSwitch.running
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                root.selectLayout(index);
                                layoutPopup.visible = false;
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.error.length > 0
                    text: root.error
                    color: Theme.red
                    wrapMode: Text.Wrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    textFormat: Text.PlainText
                }
            }
        }
    }
}
