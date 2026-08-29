pragma Singleton

import QtQuick
import Quickshell

QtObject {
    readonly property string sandboxName: "quickshell-ai-chat"
    readonly property string sbxExecutable: Quickshell.env("HOME") + "/.local/bin/sbx"
    readonly property string sandboxWorkspace: Quickshell.stateDir + "/ai-sandbox-workspace"
    readonly property bool backendAutoStart: true
    readonly property bool debug: Quickshell.env("QUICKSHELL_AI_DEBUG") === "1"
    readonly property int chatWidth: 760
    readonly property int chatMaxHeight: 980
    readonly property string sandboxWorkingDirectory: "/tmp"
    readonly property string sandboxAttachmentDirectory: "/tmp/quickshell-ai"
}
