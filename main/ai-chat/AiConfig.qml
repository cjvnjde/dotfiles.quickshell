pragma Singleton

import QtQuick
import Quickshell
import ".."

QtObject {
    readonly property string sandboxName: "quickshell-ai-chat"
    readonly property var sbxCommand: [
        "bash", Quickshell.shellPath("ai-chat/AiSbx.sh")
    ]
    readonly property string sandboxWorkspace: Quickshell.stateDir + "/ai-sandbox-workspace"
    readonly property string exportStagingDirectory: {
        const runtimeDirectory = Quickshell.env("XDG_RUNTIME_DIR");
        return runtimeDirectory.length > 0 ? runtimeDirectory : sandboxWorkspace;
    }
    readonly property string sandboxChatKitDirectory: "/home/agent/quickshell-ai-chat-kit"
    readonly property string sandboxOutputHostDirectory: sandboxWorkspace + "/outputs"
    readonly property int sandboxOutputMaxBytes: 100 * 1024 * 1024
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
