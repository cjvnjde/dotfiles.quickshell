pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
QtObject {
    id: root
    property bool recording: false
    property real started: 0
    readonly property string elapsed: {
        const seconds = Math.max(0, Math.floor(clock.date.getTime() / 1000 - started));
        return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
    }
    property SystemClock clock: SystemClock { precision: SystemClock.Seconds }
    function screenshot(full) { launch(["screenshot", full ? "full" : "region"]); }
    function toggleRecording(full, output) {
        launch(recording ? ["stop"] : ["record", full ? "full" : "region", output]);
    }
    function launch(args) {
        if (action.running) return;
        action.command = ["python3", Quickshell.shellPath("modules/capture/Capture.py")].concat(args);
        action.running = true;
    }
    property Process action: Process { onExited: status.running = true }
    property Process status: Process {
        command: ["python3", Quickshell.shellPath("modules/capture/Capture.py"), "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.recording = data.recording;
                    root.started = data.started || 0;
                } catch (error) { console.warn("Capture status:", error); }
            }
        }
    }
    property Timer poll: Timer { interval: 1500; running: true; repeat: true; onTriggered: if (!status.running) status.running = true }
}
