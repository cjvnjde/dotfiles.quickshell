pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Scope {
    id: root

    readonly property var themes: JSON.parse(catalog.text()).themes
    readonly property var theme: themes.find(
        entry => entry.id === preferences.selectedTheme) || themes[0]
    readonly property string themeId: theme.id
    readonly property string mode: SystemTheme.mode
    readonly property var palette: theme[mode]
    property string selectionError: ""

    readonly property color background: palette.background
    readonly property color surface: palette.surface
    readonly property color raised: palette.raised
    readonly property color hover: palette.hover
    readonly property color border: palette.border
    readonly property color text: palette.text
    readonly property color mutedText: palette.mutedText
    readonly property color subtleText: palette.subtleText
    readonly property color selection: palette.selection
    readonly property color selectedText: palette.selectedText
    readonly property color accent: palette.accent
    readonly property color success: palette.success
    readonly property color error: palette.error
    readonly property color action: palette.action
    readonly property color actionHover: palette.actionHover
    readonly property color actionText: palette.actionText
    readonly property color codeBackground: palette.codeBackground
    readonly property color userBackground: palette.userBackground

    function commandItems(draft) {
        const value = String(draft || "").trim().toLowerCase();
        if (!/^\/theme(?:\s|$)/.test(value)) {
            return null;
        }

        const terms = value.slice(6).trim().split(/\s+/);
        const items = [];
        for (const entry of themes) {
            for (const variant of ["light", "dark"]) {
                const label = entry.label + " · "
                    + (variant === "light" ? "Light" : "Dark");
                const searchText = (entry.id + " " + label).toLowerCase();
                if (!terms.every(term => searchText.indexOf(term) >= 0)) {
                    continue;
                }
                items.push({
                    label,
                    detail: entry.id === themeId && variant === mode
                        ? "Current theme" : "Use " + variant + " mode",
                    draft: "/theme " + entry.id + " " + variant,
                    immediate: true
                });
            }
        }
        return items;
    }

    function select(argument) {
        const pieces = String(argument || "").trim().toLowerCase().split(/\s+/);
        if (pieces.length !== 2
                || (pieces[1] !== "light" && pieces[1] !== "dark")
                || !themes.some(entry => entry.id === pieces[0])) {
            selectionError = "Unknown theme or mode. Type /theme to see available themes.";
            return false;
        }

        if (!SystemTheme.setMode(pieces[1])) {
            selectionError = SystemTheme.error;
            return false;
        }
        selectionError = "";
        preferences.selectedTheme = pieces[0];
        return true;
    }

    FileView {
        id: catalog
        path: Quickshell.shellPath("ai-chat/AiThemes.json")
        blockLoading: true
    }

    FileView {
        path: Quickshell.stateDir + "/ai-chat-theme.json"
        blockLoading: true
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: preferences
            property string selectedTheme: "catppuccin"
        }
    }
}
