pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Layout.js" as Layout
QtObject {
    id: root
    property var layout: ({left: [], center: [], right: [], centerAnchor: ""})
    property string error: ""
    function apply(text) {
        try { layout = Layout.parse(text); error = ""; if (lastGood) lastGood.setText(text); }
        catch (e) { error = String(e); console.warn("Bar layout kept unchanged:", error); }
    }
    property FileView lastGood: FileView {
        path: Quickshell.stateDir + "/bar-layout-last-good.json"
        blockLoading: true
        printErrors: false
    }
    property FileView config: FileView {
        path: Quickshell.shellPath("bar.json")
        watchChanges: true
        blockLoading: true
        onLoaded: root.apply(text())
        onFileChanged: reload()
        onLoadFailed: { root.error = "Cannot read bar.json"; console.warn(root.error); }
    }
    Component.onCompleted: {
        apply(config.text());
        if (error) {
            try { layout = Layout.parse(lastGood.text()); }
            catch (e) { console.warn("No saved working bar layout:", e); }
        }
    }
}
