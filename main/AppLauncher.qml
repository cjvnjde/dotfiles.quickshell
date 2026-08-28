import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property bool shown: false
    property int selectedIndex: 0
    property alias query: searchInput.text

    readonly property var filteredApplications: filterApplications(query)

    function fuzzyScore(text, pattern) {
        let patternIndex = 0;
        let previousMatch = -2;
        let score = 0;

        for (let index = 0; index < text.length && patternIndex < pattern.length; index++) {
            if (text[index] !== pattern[patternIndex]) {
                continue;
            }

            score += index;
            if (index === 0 || previousMatch === index - 1) {
                score -= 4;
            }

            previousMatch = index;
            patternIndex++;
        }

        return patternIndex === pattern.length ? score : -1;
    }

    function filterApplications(value) {
        const query = value.trim().toLowerCase();
        const applications = DesktopEntries.applications.values;
        const matches = [];

        for (const application of applications) {
            const name = application.name.toLowerCase();
            const genericName = application.genericName.toLowerCase();
            const comment = application.comment.toLowerCase();
            const id = application.id.toLowerCase();
            const keywords = application.keywords.join(" ").toLowerCase();
            let score = 0;

            if (query.length > 0) {
                if (name === query) {
                    score = 0;
                } else if (name.startsWith(query)) {
                    score = 1;
                } else if (name.split(/\s+/).some(word => word.startsWith(query))) {
                    score = 2;
                } else if (name.includes(query)) {
                    score = 3;
                } else if (genericName.includes(query)) {
                    score = 4;
                } else if (keywords.includes(query)) {
                    score = 5;
                } else if (comment.includes(query) || id.includes(query)) {
                    score = 6;
                } else {
                    const fuzzy = fuzzyScore(name + " " + genericName + " " + keywords, query);
                    if (fuzzy < 0) {
                        continue;
                    }

                    score = 7 + fuzzy / 1000;
                }
            }

            matches.push({
                application: application,
                score: score
            });
        }

        matches.sort((left, right) => {
            if (left.score !== right.score) {
                return left.score - right.score;
            }

            return left.application.name.localeCompare(right.application.name);
        });

        return matches.map(match => match.application);
    }

    function show() {
        query = "";
        selectedIndex = 0;
        shown = true;
    }

    function hide() {
        shown = false;
        query = "";
        selectedIndex = 0;
    }

    function toggle() {
        if (shown) {
            hide();
        } else {
            show();
        }
    }

    function moveSelection(offset) {
        const count = filteredApplications.length;

        if (count === 0) {
            selectedIndex = 0;
            return;
        }

        selectedIndex = (selectedIndex + offset + count) % count;
        applicationList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function launch(application) {
        hide();
        application.execute();
    }

    onQueryChanged: {
        selectedIndex = 0;
        applicationList.positionViewAtBeginning();
    }

    onFilteredApplicationsChanged: {
        if (selectedIndex >= filteredApplications.length) {
            selectedIndex = Math.max(0, filteredApplications.length - 1);
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }

        function show(): void {
            root.show();
        }

        function hide(): void {
            root.hide();
        }
    }

    PanelWindow {
        id: launcherWindow

        visible: root.shown
        color: "#9911111b"
        exclusiveZone: 0
        aboveWindows: true

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: {
            if (visible) {
                Qt.callLater(() => searchInput.forceActiveFocus());
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }

        Rectangle {
            id: launcherCard

            anchors.centerIn: parent
            width: Math.min(720, parent.width - 48)
            height: Math.min(600, parent.height - 96)
            radius: 4
            color: Theme.base
            border.width: 1
            border.color: Theme.lavender

            MouseArea {
                anchors.fill: parent
                onClicked: mouse => mouse.accepted = true
            }

            Rectangle {
                id: searchBox

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 12
                }
                height: 34
                radius: 4
                color: Theme.mantle
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.blue : Theme.surface1

                Text {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 12
                    }
                    text: "󰍉"
                    color: Theme.mauve
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                }

                TextInput {
                    id: searchInput

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 38
                        rightMargin: 12
                    }
                    color: Theme.text
                    selectionColor: Theme.surface2
                    selectedTextColor: Theme.text
                    clip: true
                    font.family: Theme.fontFamily
                    font.pixelSize: 14

                    Text {
                        visible: searchInput.text.length === 0
                        text: "Search applications"
                        color: Theme.overlay0
                        font: searchInput.font
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.hide();
                        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                            root.moveSelection(1);
                        } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_Backtab)) {
                            root.moveSelection(-1);
                        } else if (event.key === Qt.Key_PageDown) {
                            root.moveSelection(5);
                        } else if (event.key === Qt.Key_PageUp) {
                            root.moveSelection(-5);
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.filteredApplications.length > 0) {
                                root.launch(root.filteredApplications[root.selectedIndex]);
                            }
                        } else {
                            return;
                        }

                        event.accepted = true;
                    }
                }
            }

            ListView {
                id: applicationList

                anchors {
                    top: searchBox.bottom
                    left: parent.left
                    right: parent.right
                    bottom: footer.top
                    topMargin: 8
                    leftMargin: 8
                    rightMargin: 8
                    bottomMargin: 6
                }
                clip: true
                spacing: 2
                model: root.filteredApplications
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    readonly property bool selected: index === root.selectedIndex

                    width: ListView.view.width
                    height: 42
                    radius: 4
                    color: selected ? Theme.surface0 : appMouse.containsMouse ? Theme.mantle : "transparent"

                    Image {
                        id: appIcon

                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 10
                        }
                        width: 28
                        height: 28
                        source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                        sourceSize: Qt.size(width, height)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    Text {
                        anchors {
                            left: appIcon.right
                            right: parent.right
                            top: parent.top
                            leftMargin: 10
                            rightMargin: 10
                            topMargin: 4
                        }
                        text: modelData.name
                        color: selected ? Theme.lavender : Theme.text
                        elide: Text.ElideRight
                        font.bold: selected
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }

                    Text {
                        anchors {
                            left: appIcon.right
                            right: parent.right
                            bottom: parent.bottom
                            leftMargin: 10
                            rightMargin: 10
                            bottomMargin: 4
                        }
                        text: modelData.genericName || modelData.comment || modelData.id
                        color: Theme.subtext0
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: appMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.selectedIndex = index
                        onClicked: root.launch(modelData)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.filteredApplications.length === 0
                    text: "No applications found"
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }
            }

            Item {
                id: footer

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: 38

                Rectangle {
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        leftMargin: 18
                        rightMargin: 18
                    }
                    height: 1
                    color: Theme.surface0
                }

                Text {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 20
                    }
                    text: root.filteredApplications.length + " applications"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Text {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: 20
                    }
                    text: "↑↓ navigate   enter open   esc close"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }
        }
    }
}
