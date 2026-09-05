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
    readonly property int sandboxCheckRetryLimit: 3
    readonly property int sandboxCheckRetryDelayMs: 3000
    readonly property int sandboxWorkspaceTimeoutMs: 15000
    readonly property int sandboxCreateTimeoutMs: 300000
    readonly property int sandboxStartTimeoutMs: 60000
    function sandboxNameForProject(projectId) {
        return projectId === "general" ? sandboxName
            : sandboxName + "-" + projectId;
    }
    function sandboxWorkspaceForProject(projectId) {
        return projectId === "general" ? sandboxWorkspace
            : Quickshell.stateDir + "/ai-projects/" + projectId
                + "/sandbox-workspace";
    }
    function sandboxOutputDirectoryForProject(projectId) {
        return sandboxWorkspaceForProject(projectId) + "/outputs";
    }
    readonly property bool backendAutoStart: true
    readonly property bool debug: Quickshell.env("QUICKSHELL_AI_DEBUG") === "1"
    readonly property int chatWidth: 760
    readonly property int chatMaxHeight: 980
    readonly property string sandboxWorkingDirectory: sandboxChatKitDirectory
    readonly property string sandboxAttachmentDirectory: "/tmp/quickshell-ai"
}
