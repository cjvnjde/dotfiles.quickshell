pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
QtObject {
    id: root
    // Same geometry source as Omarchy's Style singleton.
    property int cornerRadius: 0
    property int gapsOut: 5
    function refresh() { rounding.running = true; gaps.running = true; }
    Component.onCompleted: refresh()
    property Process rounding: Process {
        command: ["hyprctl", "getoption", "decoration:rounding", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { root.cornerRadius = Math.max(0, JSON.parse(text).int); } catch (e) {} } }
    }
    property Process gaps: Process {
        command: ["hyprctl", "getoption", "general:gaps_out", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { const data = JSON.parse(text); const values = String(data.css || "").match(/-?\d+(?:\.\d+)?/g) || []; const n = values.length ? Number(values[0]) : Number(data.int); if (isFinite(n)) root.gapsOut = Math.max(0, Math.round(n / 2)); } catch (e) {} } }
    }
    property Connections events: Connections { target: Hyprland; function onRawEvent(event) { if (event.name === "configreloaded") root.refresh(); } }
}
