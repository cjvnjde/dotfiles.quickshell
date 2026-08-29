pragma Singleton

import QtQuick
import Quickshell

QtObject {
    readonly property string sandboxName: "quickshell-ai-chat"
    readonly property var sbxCommand: [
        "bash", Quickshell.shellPath("AiSbx.sh")
    ]
    readonly property string sandboxWorkspace: Quickshell.stateDir + "/ai-sandbox-workspace"
    readonly property string sandboxChatKitDirectory: "/home/agent/quickshell-ai-chat-kit"
    readonly property int sandboxCheckTimeoutMs: 20000
    readonly property int sandboxWorkspaceTimeoutMs: 15000
    readonly property int sandboxCreateTimeoutMs: 300000
    readonly property bool backendAutoStart: true
    readonly property bool debug: Quickshell.env("QUICKSHELL_AI_DEBUG") === "1"
    readonly property int chatWidth: 760
    readonly property int chatMaxHeight: 980
    readonly property string sandboxWorkingDirectory: sandboxChatKitDirectory
    readonly property string sandboxAttachmentDirectory: "/tmp/quickshell-ai"
}
