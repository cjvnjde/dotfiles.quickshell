import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Scope {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool microphoneMuted: source?.audio?.muted ?? false
    property bool microphoneActive: false
    property bool cameraActive: false
    property bool screenActive: false

    PwObjectTracker { objects: [root.sink, root.source] }

    // Read graph state, not permission grants or merely connected devices.
    // One shared probe for all monitors; no camera or microphone is opened.
    Process {
        id: probe
        command: ["pw-dump"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const graph = JSON.parse(text);
                    const nodes = graph.filter(o => o.type === "PipeWire:Interface:Node");
                    const activeLinks = graph.filter(o => o.type === "PipeWire:Interface:Link"
                        && o.info?.state === "active");
                    let mic = false, camera = false, screen = false;
                    for (const node of nodes) {
                        const info = node.info || {};
                        const p = info.props || {};
                        if (info.state !== "running") continue;
                        const cls = p["media.class"] || "";
                        if (cls === "Audio/Source") {
                            // Follow capture at the source: effects and JACK clients need
                            // not expose a Stream/Input/Audio node. Sink monitors do not count.
                            mic = mic || activeLinks.some(link =>
                                Number(link.info["output-node-id"]) === node.id);
                        }
                        if (cls !== "Video/Source") continue;
                        const identity = [p["node.name"], p["media.name"], p["media.role"],
                            p["application.name"]].join(" ").toLowerCase();
                        const isCamera = p["device.api"] === "v4l2" || p["device.api"] === "libcamera"
                            || /camera|v4l2|libcamera/.test(identity);
                        const isScreen = /screen|screencast|xdg-desktop-portal|hyprland/.test(identity);
                        camera = camera || isCamera;
                        screen = screen || (!isCamera && isScreen);
                    }
                    root.microphoneActive = mic;
                    root.cameraActive = camera;
                    root.screenActive = screen;
                } catch (error) {
                    console.warn("Privacy graph could not be read:", error);
                }
            }
        }
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: { if (!probe.running) probe.running = true; }
    }
}
