import QtQuick
import Quickshell
import Quickshell.Io
import ".."

PanelWindow {
    id: root
    required property var aiController
    required property var notificationController
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: Theme.base
    property var revealed: ({left: false, center: false, right: false})
    function sectionRevealed(name) { return revealed[name] === true; }
    function revealSection(name, value) {
        const next = Object.assign({}, revealed); next[name] = value; revealed = next;
    }
    function toggleSection(name) { revealSection(name, !sectionRevealed(name)); }
    function revealAt(x) {
        for (const item of [leftSection, centerSection, rightSection]) {
            if (x >= item.x - 4 && x <= item.x + item.width + 4) revealSection(item.section, true);
        }
    }
    IpcHandler {
        target: "bar"
        function status(): string {
            return JSON.stringify({revealed: root.revealed, configError: BarSettings.error,
                moduleErrors: Object.assign({}, leftSection.loadErrors, centerSection.loadErrors, rightSection.loadErrors),
                sections: {left: leftSection.geometry(), center: centerSection.geometry(), right: rightSection.geometry()},
                centerAnchor: BarSettings.layout.centerAnchor,
                anchorX: centerSection.x + centerSection.anchorCenter,
                width: root.width});
        }
        function reload(): void { Quickshell.reload(true); }
    }
    HoverHandler {
        id: barHover
        blocking: false
        onPointChanged: if (hovered) root.revealAt(point.position.x)
        onHoveredChanged: {
            if (hovered) { fold.stop(); root.revealAt(point.position.x); }
            else fold.restart();
        }
    }
    Timer {
        id: fold
        interval: Theme.hoverDelay
        onTriggered: if (!barHover.hovered) root.revealed = {left: false, center: false, right: false};
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1; color: Theme.surface0; opacity: 0.5
    }
    BarSection {
        id: leftSection
        bar: root; section: "left"; entries: BarSettings.layout.left
        revealed: root.sectionRevealed(section)
        x: Theme.barMargin; y: 2; height: root.height - 4
    }
    BarSection {
        id: centerSection
        bar: root; section: "center"; entries: BarSettings.layout.center
        anchorId: BarSettings.layout.centerAnchor
        revealed: root.sectionRevealed(section)
        x: root.width / 2 - anchorCenter
        y: 2; height: root.height - 4
    }
    BarSection {
        id: rightSection
        bar: root; section: "right"; entries: BarSettings.layout.right
        revealed: root.sectionRevealed(section)
        x: root.width - width - Theme.barMargin
        y: 2; height: root.height - 4
    }
}
