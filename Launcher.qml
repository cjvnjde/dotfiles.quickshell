pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
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
    property bool calculatorAvailable: false

    // Catppuccin Mocha palette.
    readonly property var theme: QtObject {
        readonly property color base: "#1e1e2e"
        readonly property color mantle: "#181825"
        readonly property color surface0: "#313244"
        readonly property color surface1: "#45475a"
        readonly property color surface2: "#585b70"
        readonly property color text: "#cdd6f4"
        readonly property color subtext0: "#a6adc8"
        readonly property color blue: "#89b4fa"
        readonly property color lavender: "#b4befe"
        readonly property string fontFamily: "FiraCode Nerd Font"
    }

    readonly property var builtinTools: calculatorAvailable ? [
        {
            key: "tool:calculator",
            name: "Calculator",
            subtitle: "Evaluate an expression with qalc",
            icon: "accessories-calculator",
            action: "calculator",
            keywords: "calculate arithmetic math expression"
        }
    ] : []
    readonly property var filteredResults: filterResults(query, cliCommands, history.entries)
    readonly property string calculationExpression: calculatorExpression(query)
    property string calculationResult: ""
    property string calculationResultExpression: ""
    readonly property bool calculationResultCurrent: calculationResultExpression.length > 0
        && calculationResultExpression === calculationExpression
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
        if (!calculatorAvailable)
            return "";
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

        // A known executable takes precedence over automatic math detection.
        if (!explicit && cliCommands.indexOf(expression.split(/\s+/, 1)[0]) !== -1)
            return "";

        const hasNumberOperation = /\d/.test(expression) && /[+\-*/%^!×÷()]/.test(expression);
        const hasMathName = /\b(?:abs|acos|asin|atan|ceil|cos|exp|floor|ln|log|max|min|pi|pow|round|sin|sqrt|tan)\b/i.test(expression);
        return expression.length > 0 && (explicit || hasNumberOperation || hasMathName)
            ? expression
            : "";
    }

    function startPendingCalculation() {
        if (pendingCalculation.length === 0 || calculationTimer.running || calculatorProcess.running) {
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
        calculatorProbe.running = true;
        // Refresh in the background so newly installed commands appear.
        if (!commandIndexer.running)
            commandIndexer.running = true;
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

        selectedIndex = ((selectedIndex + offset) % count + count) % count;
        applicationList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    // keepOpen: leave the window open after the command exits, so its output stays readable.
    function launchInTerminal(command, workingDirectory, keepOpen) {
        const terminal = keepOpen ? ["ghostty", "--wait-after-command=true", "-e"] : ["ghostty", "-e"];
        Quickshell.execDetached({
            command: terminal.concat(command),
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
            launchInTerminal(["bash", "-lc", result.commandLine], "", true);
        } else {
            launchInTerminal([result.command], "", true);
        }
    }

    onQueryChanged: {
        selectedIndex = 0;
        applicationList.positionViewAtBeginning();
    }

    onCalculationExpressionChanged: {
        pendingCalculation = calculationExpression;

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
            "IFS=:; for directory in $PATH; do [[ -d \"$directory\" ]] || continue; for executable in \"$directory\"/*; do if [[ -f \"$executable\" && -x \"$executable\" ]]; then printf '%s\\n' \"${executable##*/}\"; fi; done; done"
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

    Process {
        id: calculatorProbe
        command: ["sh", "-c", "command -v qalc >/dev/null 2>&1"]
        onExited: exitCode => root.calculatorAvailable = exitCode === 0
    }

    Component.onCompleted: {
        commandIndexer.running = true;
        calculatorProbe.running = true;
    }

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

        command: ["qalc", "--terse", "--set", "color 0", "--", root.runningCalculation]

        stdout: StdioCollector {
            id: calculatorOutput
        }

        stderr: StdioCollector {}

        onExited: function(exitCode) {
            const expression = root.runningCalculation;
            const output = calculatorOutput.text.trim();
            root.runningCalculation = "";

            if (expression === root.calculationExpression) {
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
            width: Math.min(560, parent.width - 48)
            height: Math.min(436, parent.height - 96)
            radius: 4
            color: root.theme.base

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
                height: 42
                radius: 4
                color: root.theme.mantle

                Text {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 12
                    }
                    text: "󰍉"
                    color: root.theme.subtext0
                    font.family: root.theme.fontFamily
                    font.pixelSize: 16
                }

                TextField {
                    id: searchInput
                    objectName: "launcherSearchInput"

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 38
                        rightMargin: 12
                    }
                    color: root.theme.text
                    selectionColor: root.theme.surface2
                    selectedTextColor: root.theme.text
                    placeholderTextColor: root.theme.subtext0
                    selectByMouse: true
                    topPadding: 0
                    bottomPadding: 0
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    font.family: root.theme.fontFamily
                    font.pixelSize: 14

                    background: null
                    leftPadding: 0
                    rightPadding: 0
                    placeholderText: "Search…"
                    height: parent.height

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
                            if (root.calculationResultCurrent && root.calculationResult.length > 0) {
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
                    color: root.theme.lavender
                    horizontalAlignment: Text.AlignHCenter
                    font.bold: true
                    font.family: root.theme.fontFamily
                    font.pixelSize: 16
                }

                Text {
                    anchors {
                        left: calculationIcon.right
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                        rightMargin: 10
                    }
                    text: root.calculationResultCurrent ? root.calculationResult : "…"
                    color: root.theme.text
                    elide: Text.ElideRight
                    font.family: root.theme.fontFamily
                    font.pixelSize: 14
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.copyCalculation()
                }
            }

            ListView {
                id: applicationList
                objectName: "launcherResults"

                anchors {
                    top: calculationCard.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    topMargin: 8
                    leftMargin: 8
                    rightMargin: 8
                    bottomMargin: 8
                }
                clip: true
                spacing: 2
                model: root.filteredResults
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                highlightResizeDuration: 0

                delegate: Rectangle {
                    id: applicationRow

                    required property var modelData
                    required property int index

                    readonly property bool selected: !(root.calculationResultCurrent && root.calculationResult.length > 0) && index === root.selectedIndex
                    readonly property bool isCommand: modelData.kind === "command"
                    readonly property bool hovered: appMouse.containsMouse

                    width: ListView.view.width
                    height: 44
                    radius: 4
                    color: selected ? root.theme.surface0 : hovered ? root.theme.mantle : "transparent"

                    Item {
                        id: appIcon

                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 10
                        }
                        width: 28
                        height: 28

                        Image {
                            id: themedIcon
                            objectName: "launcherResultIcon"

                            anchors.fill: parent
                            visible: status === Image.Ready
                            source: Quickshell.iconPath(
                                applicationRow.isCommand ? "utilities-terminal" : (applicationRow.modelData.icon || ""),
                                true
                            )
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        // Keep the result type recognizable even with a missing icon theme.
                        Rectangle {
                            objectName: "launcherFallbackIcon"
                            anchors.centerIn: parent
                            width: 24
                            height: 20
                            visible: themedIcon.status !== Image.Ready
                            radius: 3
                            color: root.theme.surface0

                            Rectangle {
                                anchors {
                                    top: parent.top
                                    left: parent.left
                                    right: parent.right
                                    topMargin: 5
                                    leftMargin: 1
                                    rightMargin: 1
                                }
                                visible: !applicationRow.isCommand && !applicationRow.modelData.toolAction
                                height: 1
                                color: root.theme.subtext0
                            }

                            Text {
                                anchors.centerIn: parent
                                text: applicationRow.isCommand ? ">_" : applicationRow.modelData.toolAction === "calculator" ? "=" : ""
                                color: root.theme.subtext0
                                font.family: root.theme.fontFamily
                                font.pixelSize: 12
                            }
                        }
                    }

                    Text {
                        anchors {
                            left: appIcon.right
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 12
                            rightMargin: 10
                        }
                        text: applicationRow.modelData.name
                        color: root.theme.text
                        elide: Text.ElideRight
                        font.family: root.theme.fontFamily
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: appMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // Hover is only a visual hint; Enter always uses selectedIndex.
                        onClicked: {
                            root.selectedIndex = applicationRow.index;
                            root.launch(applicationRow.modelData);
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.filteredResults.length === 0 && root.calculationResult.length === 0
                    text: "No results found"
                    color: root.theme.subtext0
                    font.family: root.theme.fontFamily
                    font.pixelSize: 14
                }
            }
        }
    }
}
