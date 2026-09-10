pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var record: null
    readonly property bool available: record !== null && record.available === true
    readonly property bool refreshing: collector.running
    property string error: ""
    property string pendingKind: ""
    property int refreshIntervalSec: 900

    function refresh(kind) {
        kind = kind || "normal";
        if (collector.running) {
            // A full rescan outranks a limits-only refresh, even across monitors.
            const priority = { "": 0, "limits": 1, "normal": 2, "force": 3 };
            if (priority[kind] > priority[pendingKind]) {
                pendingKind = kind;
            }
            return;
        }
        const command = ["python3", Quickshell.shellPath("topbar/CodexUsage.py")];
        if (kind === "force") {
            command.push("--force");
        } else if (kind === "limits") {
            command.push("--limits-only");
        }
        collector.command = command;
        collector.running = true;
    }

    function acceptRecord(text) {
        try {
            const next = JSON.parse(text);
            if (!next || next.schemaVersion !== 1 || next.id !== "codex"
                    || typeof next.available !== "boolean"
                    || !Number.isFinite(next.todayTotalTokens)
                    || !Array.isArray(next.recentDays) || !Array.isArray(next.limits)
                    || !next.modelUsage || typeof next.modelUsage !== "object") {
                throw new Error("Unsupported Codex usage record");
            }
            record = next;
            error = "";
        } catch (exception) {
            // Keep the last successful snapshot visibly stale, not a false zero.
            error = "Could not read Codex usage: " + exception.message;
        }
    }

    Timer {
        interval: Math.max(30, root.refreshIntervalSec) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh("normal")
    }

    Process {
        id: collector
        stdout: StdioCollector { id: collectorOutput }
        stderr: StdioCollector { id: collectorError }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0 || exitStatus !== 0) {
                root.error = "Codex usage refresh failed: "
                    + (collectorError.text.trim() || "exit " + exitCode);
            } else {
                root.acceptRecord(collectorOutput.text);
                if (collectorError.text.trim()) {
                    console.warn("Codex usage:", collectorError.text.trim());
                }
            }
            if (root.pendingKind) {
                const kind = root.pendingKind;
                root.pendingKind = "";
                Qt.callLater(function() { root.refresh(kind); });
            }
        }
    }
}
