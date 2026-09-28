pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
QtObject {
    id: root
    property var location: null
    property var report: null
    property var suggestions: []
    property string error: ""
    property string updated: ""
    property string operation: ""
    readonly property bool busy: process.running
    function launch(args, kind) {
        if (busy) return;
        operation = kind; error = "";
        process.command = ["python3", Quickshell.shellPath("modules/weather/Weather.py")].concat(args);
        process.running = true;
    }
    function search(name) { if (name.trim().length > 1) launch(["search", name.trim()], "search"); }
    function refresh() { if (location) launch(["forecast", String(location.latitude), String(location.longitude)], "forecast"); }
    function selectLocation(value) {
        location = value; suggestions = []; report = null; updated = ""; save(); refresh();
    }
    function save() { file.setText(JSON.stringify({location: location, report: report, updated: updated})); }
    Component.onCompleted: {
        try { const saved = JSON.parse(file.text()); location = saved.location || null; report = saved.report || null; updated = saved.updated || ""; } catch (e) {}
        refresh();
    }
    property IpcHandler ipc: IpcHandler {
        target: "weather"
        function search(city: string): void { root.search(city); }
        function choose(index: int): void { if (!root.busy && index >= 0 && index < root.suggestions.length) root.selectLocation(root.suggestions[index]); }
        function clear(): void { if (!root.busy) { root.location = null; root.report = null; root.suggestions = []; root.updated = ""; root.error = ""; root.save(); } }
        function status(): string { return JSON.stringify({location: root.location, busy: root.busy, error: root.error, suggestions: root.suggestions.length, forecast: !!root.report}); }
    }
    property FileView file: FileView { path: Quickshell.stateDir + "/weather.json"; blockLoading: true; printErrors: false }
    property Timer poll: Timer { interval: 1800000; running: !!root.location; repeat: true; onTriggered: root.refresh() }
    property Process process: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (data.error) { root.error = String(data.reason || data.error); return; }
                    if (root.operation === "search") { root.suggestions = data.results || []; if (!root.suggestions.length) root.error = "No matching cities"; }
                    else { root.report = data; root.updated = new Date().toISOString(); root.save(); }
                } catch (e) { root.error = "Could not read weather response"; }
            }
        }
    }
}
