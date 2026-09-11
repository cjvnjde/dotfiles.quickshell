import QtQuick
import QtTest
import Quickshell

// Run with test_launcher.py. Launches are intercepted; no applications open.
ShellRoot {
    id: testRoot

    readonly property var fixtures: [
        { key: "application:browser", kind: "application", name: "Firefox", icon: "firefox" },
        { key: "application:files", kind: "application", name: "Files", icon: "system-file-manager" },
        { key: "command:git", kind: "command", name: "git status", icon: "utilities-terminal" },
        { key: "application:missing", kind: "application", name: "Missing icon", icon: "" },
        { key: "tool:calculator", kind: "tool", name: "Calculator", icon: "accessories-calculator", toolAction: "calculator" }
    ]
    property var results: fixtures
    property string launchedKey: ""
    property int launchedIndex: -1

    AppLauncher {
        id: launcher
        shown: false

        function filterResults(value, commands, usageEntries) {
            return testRoot.results;
        }

        function launch(result) {
            testRoot.launchedKey = result.key;
            testRoot.launchedIndex = selectedIndex;
        }
    }

    TestCase {
        id: tests
        name: "AppLauncher"
        when: true

        property var input
        property var list

        onCompletedChanged: {
            if (completed) {
                console.warn("LAUNCHER_TEST_RESULTS", JSON.stringify({
                    passed: qtest_results.passCount,
                    failed: qtest_results.failCount,
                    skipped: qtest_results.skipCount
                }));
            }
        }

        function cleanup() {
            console.warn("LAUNCHER_TEST", qtest_results.functionName,
                qtest_results.failed ? "FAIL" : "PASS");
        }

        function initTestCase() {
            // Scope.children is append-only; search its QObject hierarchy directly.
            input = qtest_results.findChild(launcher, "launcherSearchInput");
            list = qtest_results.findChild(launcher, "launcherResults");
            verify(input !== null, "Search input found");
            verify(list !== null, "Result list found");
            parent = input;
        }

        function press(key) {
            keyClick(key);
            wait(50); // Allow the window system to deliver the injected key event.
        }

        function init() {
            testRoot.results = testRoot.fixtures;
            testRoot.launchedKey = "";
            testRoot.launchedIndex = -1;
            launcher.show();
            input.Window.window.requestActivate();
            input.forceActiveFocus();
            tryCompare(input, "activeFocus", true);
            tryCompare(list, "count", testRoot.results.length);
            tryVerify(() => list.itemAtIndex(3) !== null);
            mouseMove(input, 2, 2);
        }

        function test_hover_does_not_change_enter_target() {
            press(Qt.Key_Down);
            compare(launcher.selectedIndex, 1);
            const hoveredRow = list.itemAtIndex(3);
            mouseMove(hoveredRow, hoveredRow.width / 2, hoveredRow.height / 2);
            tryCompare(hoveredRow, "hovered", true);
            compare(launcher.selectedIndex, 1);
            compare(list.itemAtIndex(1).selected, true);
            compare(hoveredRow.selected, false);
            compare(testRoot.launchedKey, "");
            press(Qt.Key_Return);
            compare(testRoot.launchedKey, testRoot.fixtures[1].key);
            press(Qt.Key_Down);
            compare(launcher.selectedIndex, 2);
        }

        function test_click_selects_and_opens_clicked_result() {
            const row = list.itemAtIndex(2);
            mouseClick(row, row.width / 2, row.height / 2);
            compare(launcher.selectedIndex, 2);
            compare(testRoot.launchedIndex, 2);
            compare(testRoot.launchedKey, testRoot.fixtures[2].key);
        }

        function test_query_reset_ignores_stationary_pointer() {
            const row = list.itemAtIndex(3);
            mouseMove(row, row.width / 2, row.height / 2);
            tryCompare(row, "hovered", true);
            press(Qt.Key_Down);
            launcher.query = "new query";
            testRoot.results = testRoot.fixtures.slice().reverse();
            wait(50);
            compare(launcher.selectedIndex, 0);
            press(Qt.Key_Enter);
            compare(testRoot.launchedKey, testRoot.results[0].key);
        }

        function test_arrows_wrap_and_empty_results_are_safe() {
            press(Qt.Key_Up);
            compare(launcher.selectedIndex, testRoot.fixtures.length - 1);
            press(Qt.Key_Down);
            compare(launcher.selectedIndex, 0);
            testRoot.results = [];
            tryCompare(list, "count", 0);
            press(Qt.Key_Down);
            press(Qt.Key_Return);
            compare(launcher.selectedIndex, 0);
            compare(testRoot.launchedKey, "");
        }

        function test_command_and_app_icons_are_distinct() {
            compare(list.itemAtIndex(0).isCommand, false);
            compare(list.itemAtIndex(2).isCommand, true);
            compare(list.itemAtIndex(3).isCommand, false);
            const commandIcon = findChild(list.itemAtIndex(2), "launcherResultIcon");
            compare(commandIcon.source.toString(), Quickshell.iconPath("utilities-terminal", true));
            const fallback = findChild(list.itemAtIndex(3), "launcherFallbackIcon");
            compare(fallback.visible, true);
        }

        function test_scrolling_does_not_change_selection() {
            testRoot.results = testRoot.fixtures.concat(testRoot.fixtures, testRoot.fixtures);
            tryCompare(list, "count", 15);
            press(Qt.Key_Down);
            mouseMove(list, list.width / 2, list.height / 2);
            mouseWheel(list, list.width / 2, list.height / 2, 0, -240);
            tryVerify(() => list.contentY > 0);
            tryCompare(list, "moving", false);
            compare(launcher.selectedIndex, 1);
            press(Qt.Key_Return);
            compare(testRoot.launchedKey, testRoot.fixtures[1].key);
        }

        function test_visual_snapshot() {
            const directory = Quickshell.env("LAUNCHER_SCREENSHOT_DIR");
            if (!directory)
                return;
            testRoot.results = testRoot.fixtures.concat([
                { key: "application:terminal", kind: "application", name: "Terminal", icon: "utilities-terminal" },
                { key: "application:settings", kind: "tool", name: "Settings", icon: "preferences-system" },
                { key: "application:editor", kind: "application", name: "Text Editor", icon: "accessories-text-editor" }
            ]);
            tryCompare(list, "count", 8);
            const hoveredRow = list.itemAtIndex(2);
            mouseMove(hoveredRow, hoveredRow.width / 2, hoveredRow.height / 2);
            tryCompare(hoveredRow, "hovered", true);
            wait(200);
            grabImage(list.parent).save(directory + "/launcher.png");
        }

        function test_escape_and_reopen_reset_selection() {
            press(Qt.Key_Down);
            press(Qt.Key_Escape);
            compare(launcher.shown, false);
            launcher.show();
            compare(launcher.selectedIndex, 0);
            compare(launcher.query, "");
        }
    }
}
