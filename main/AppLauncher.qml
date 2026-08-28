import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "LauncherSearch.js" as LauncherSearch

Scope {
    id: root

    property bool shown: false
    property int selectedIndex: 0
    property alias query: searchInput.text
    property var cliCommands: []

    readonly property var builtinTools: [
        {
            key: "tool:calculator",
            name: "Calculator",
            subtitle: "Evaluate an expression with qalc",
            icon: "accessories-calculator",
            action: "calculator",
            keywords: "calculate arithmetic math expression"
        }
    ]
    readonly property var filteredResults: filterResults(query, cliCommands, history.entries)
    property string calculationResult: ""
    property string calculationResultExpression: ""
    readonly property bool calculationResultCurrent: calculationResultExpression.length > 0
        && calculationResultExpression === calculatorExpression(query)
    property string pendingCalculation: ""
    property string runningCalculation: ""

    function filterResults(value, commands, usageEntries) {
        return LauncherSearch.buildResults(
            DesktopEntries.applications.values,
            commands,
            builtinTools,
            value,
            usageEntries,
            Date.now(),
            200
        );
    }

    function recordUsage(result) {
        const current = history.entries || {};
        const previous = current[result.key] || {};
        const updated = {};
        for (const key in current) {
            updated[key] = current[key];
        }
        updated[result.key] = {
            count: (Number(previous.count) || 0) + 1,
            lastUsed: Date.now()
        };
        history.entries = updated;
    }

    function calculatorExpression(value) {
        let expression = value.trim();
        let explicit = false;

        if (expression.toLowerCase().startsWith("calc ")) {
            explicit = true;
            expression = expression.slice(5).trim();
        } else if (expression.startsWith("=")) {
            explicit = true;
            expression = expression.slice(1).trim();
        }

        if (expression.endsWith("=")) {
            explicit = true;
            expression = expression.slice(0, -1).trim();
        }

        const hasNumberOperation = /\d/.test(expression) && /[+\-*/%^!×÷()]/.test(expression);
        const hasMathName = /\b(?:abs|acos|asin|atan|ceil|cos|exp|floor|ln|log|max|min|pi|pow|round|sin|sqrt|tan)\b/i.test(expression);
        return expression.length > 0 && (explicit || hasNumberOperation || hasMathName)
            ? expression
            : "";
    }

    function startPendingCalculation() {
        if (pendingCalculation.length === 0) {
            return;
        }

        runningCalculation = pendingCalculation;
        pendingCalculation = "";
        calculatorProcess.running = true;
    }

    function copyCalculation() {
        if (calculationResult.length === 0 || !calculationResultCurrent) {
            return;
        }

        Quickshell.clipboardText = calculationResult;
        hide();
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
        const count = filteredResults.length;

        if (count === 0) {
            selectedIndex = 0;
            return;
        }

        selectedIndex = (selectedIndex + offset + count) % count;
        applicationList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function launchInTerminal(command, workingDirectory) {
        Quickshell.execDetached({
            command: ["ghostty", "-e"].concat(command),
            workingDirectory: workingDirectory || ""
        });
    }

    function launch(result) {
        recordUsage(result);

        if (result.toolAction === "calculator") {
            query = "=";
            Qt.callLater(() => searchInput.forceActiveFocus());
            return;
        }

        hide();
        if (result.application) {
            if (result.application.runInTerminal) {
                launchInTerminal(result.application.command, result.application.workingDirectory);
            } else {
                result.application.execute();
            }
        } else if (result.commandLine) {
            launchInTerminal(["bash", "-lc", result.commandLine], "");
        } else {
            launchInTerminal([result.command], "");
        }
    }

    onQueryChanged: {
        selectedIndex = 0;
        applicationList.positionViewAtBeginning();
        pendingCalculation = calculatorExpression(query);

        if (pendingCalculation.length === 0) {
            calculationTimer.stop();
            calculationResult = "";
            calculationResultExpression = "";
            if (calculatorProcess.running) {
                calculatorProcess.running = false;
            }
        } else {
            calculationTimer.restart();
        }
    }

    onFilteredResultsChanged: {
        if (selectedIndex >= filteredResults.length) {
            selectedIndex = Math.max(0, filteredResults.length - 1);
        }
    }

    FileView {
        id: historyFile

        path: Quickshell.stateDir + "/launcher-history.json"
        blockLoading: true
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: history

            property var entries: ({})
        }
    }

    Process {
        id: commandIndexer

        command: [
            "bash",
            "-lc",
            "IFS=:; for directory in $PATH; do [[ -d \"$directory\" ]] || continue; for executable in \"$directory\"/*; do [[ -f \"$executable\" && -x \"$executable\" ]] && printf '%s\\n' \"${executable##*/}\"; done; done"
        ]

        stdout: StdioCollector {
            id: commandIndexOutput
        }

        stderr: StdioCollector {}

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                return;
            }

            const unique = {};
            const indexedCommands = commandIndexOutput.text.split(/\r?\n/);
            for (const command of indexedCommands) {
                if (command.length > 0) {
                    unique[command] = true;
                }
            }
            root.cliCommands = Object.keys(unique).sort((left, right) => left.localeCompare(right));
        }
    }

    Component.onCompleted: commandIndexer.running = true

    Timer {
        id: calculationTimer

        interval: 100
        repeat: false
        onTriggered: {
            if (calculatorProcess.running) {
                calculatorProcess.running = false;
            } else {
                root.startPendingCalculation();
            }
        }
    }

    Process {
        id: calculatorProcess

        command: ["qalc", "--terse", "--set", "color 0", root.runningCalculation]

        stdout: StdioCollector {
            id: calculatorOutput
        }

        stderr: StdioCollector {}

        onExited: function(exitCode) {
            const expression = root.runningCalculation;
            const output = calculatorOutput.text.trim();
            root.runningCalculation = "";

            if (expression === root.calculatorExpression(root.query)) {
                if (exitCode === 0
                        && output.length > 0
                        && !output.toLowerCase().startsWith("error:")) {
                    root.calculationResult = output;
                    root.calculationResultExpression = expression;
                } else {
                    root.calculationResult = "";
                    root.calculationResultExpression = "";
                }
            }

            if (root.pendingCalculation.length > 0) {
                Qt.callLater(() => root.startPendingCalculation());
            }
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
        color: "transparent"
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
                        text: "Search applications, commands, or calculate"
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
                            if (root.calculationResult.length > 0) {
                                root.copyCalculation();
                            } else if (root.filteredResults.length > 0) {
                                root.launch(root.filteredResults[root.selectedIndex]);
                            }
                        } else {
                            return;
                        }

                        event.accepted = true;
                    }
                }
            }

            Item {
                id: calculationCard

                anchors {
                    top: searchBox.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: visible ? 8 : 0
                    leftMargin: 8
                    rightMargin: 8
                }
                visible: root.calculationResult.length > 0
                height: visible ? 42 : 0

                Text {
                    id: calculationIcon

                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                    }
                    width: 28
                    text: "="
                    color: Theme.lavender
                    horizontalAlignment: Text.AlignHCenter
                    font.bold: true
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                }

                Text {
                    anchors {
                        left: calculationIcon.right
                        right: parent.right
                        top: parent.top
                        leftMargin: 10
                        rightMargin: 10
                        topMargin: 4
                    }
                    text: root.calculationResult
                    color: Theme.lavender
                    elide: Text.ElideRight
                    font.bold: true
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                Text {
                    anchors {
                        left: calculationIcon.right
                        right: parent.right
                        bottom: parent.bottom
                        leftMargin: 10
                        rightMargin: 10
                        bottomMargin: 4
                    }
                    text: root.calculationResultCurrent
                        ? "Calculation · Enter to copy"
                        : "Calculating…"
                    color: Theme.subtext0
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.copyCalculation()
                }
            }

            ListView {
                id: applicationList

                anchors {
                    top: calculationCard.bottom
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
                model: root.filteredResults
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    readonly property bool selected: root.calculationResult.length === 0 && index === root.selectedIndex

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
                        text: modelData.kindLabel + (modelData.subtitle ? " · " + modelData.subtitle : "")
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
                    visible: root.filteredResults.length === 0 && root.calculationResult.length === 0
                    text: "No results found"
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
                    text: root.filteredResults.length + (root.filteredResults.length === 1 ? " result" : " results")
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
                    text: root.calculationResult.length > 0
                        ? "enter copy   esc close"
                        : "↑↓ navigate   enter open   esc close"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }
        }
    }
}
