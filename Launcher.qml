import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// App launcher. Toggle with: qs ipc call launcher toggle
PanelWindow {
    id: root
    visible: false
    implicitWidth: 500
    implicitHeight: 400
    color: "#1e1e2e"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.visible = !root.visible;
            if (root.visible) {
                search.text = "";
                search.forceActiveFocus();
            }
        }
    }

    property var apps: DesktopEntries.applications.values
        .filter(a => !a.noDisplay && a.name.toLowerCase().includes(search.text.toLowerCase()))
        .sort((a, b) => a.name.localeCompare(b.name))

    function launch(index) {
        if (index >= 0 && index < apps.length) {
            apps[index].execute();
            root.visible = false;
        }
    }

    TextField {
        id: search
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        placeholderText: "Search apps"
        onTextChanged: list.currentIndex = 0
        onAccepted: root.launch(list.currentIndex)
        Keys.onEscapePressed: root.visible = false
        Keys.onDownPressed: list.incrementCurrentIndex()
        Keys.onUpPressed: list.decrementCurrentIndex()
    }

    ListView {
        id: list
        anchors.top: search.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        clip: true
        model: root.apps

        delegate: Text {
            required property var modelData
            required property int index
            width: ListView.view.width
            padding: 6
            text: modelData.name
            color: ListView.isCurrentItem ? "#ffffff" : "#a6adc8"
            font.pixelSize: 15

            MouseArea {
                anchors.fill: parent
                onClicked: root.launch(parent.index)
            }
        }
    }
}
