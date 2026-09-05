import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    required property string projectId
    readonly property string sandboxName: AiConfig.sandboxNameForProject(projectId)
    readonly property string workspace: AiConfig.sandboxWorkspaceForProject(projectId)
    property string state: "idle"
    property string lastError: ""
    property int discoveryFailures: 0
    property bool timedOut: false
    property bool restartRequested: false
    readonly property bool ready: state === "ready"
    readonly property bool running: discovery.running || discoveryRetry.running
        || resetWorkspace.running || prepareWorkspace.running || createSandbox.running
        || (startSandbox.running && state !== "ready")

    signal created()
    signal finished(bool succeeded)

    function start() {
        if (state === "idle" && startSandbox.running) {
            restartRequested = true;
            return;
        }
        if (running || (state !== "idle" && state !== "error")) {
            return;
        }
        timedOut = false;
        discoveryFailures = 0;
        lastError = "";
        beginStage("checking", AiConfig.sandboxCheckTimeoutMs);
        discovery.running = true;
    }

    function invalidate() {
        restartRequested = false;
        state = "idle";
        lastError = "";
        startSandbox.running = false;
    }

    function beginStage(stage, timeoutMs) {
        state = stage;
        deadline.interval = timeoutMs;
        deadline.restart();
    }

    function fail(message) {
        deadline.stop();
        discoveryRetry.stop();
        lastError = message;
        state = "error";
        finished(false);
    }

    function warmSandbox() {
        beginStage("starting", AiConfig.sandboxStartTimeoutMs);
        startSandbox.running = true;
    }

    Timer {
        id: deadline

        repeat: false
        onTriggered: {
            root.timedOut = true;
            for (const process of [discovery, resetWorkspace, prepareWorkspace,
                    createSandbox, startSandbox]) {
                if (process.running) {
                    process.signal(9);
                }
            }
            // Wait for the child to exit before allowing another setup attempt.
        }
    }

    function stageExited() {
        deadline.stop();
        if (!timedOut) {
            return true;
        }
        if (state === "checking") {
            fail("sbx ls timed out. Run sbx ls in a terminal, resolve Docker "
                + "sign-in or sandboxd, then use /reconnect.");
        } else if (state === "creating") {
            fail("sbx create timed out. Run sbx diagnose in a terminal, "
                + "then use /reconnect.");
        } else if (state === "starting") {
            fail("Starting the sandbox timed out. Run sbx diagnose in a terminal, "
                + "then use /reconnect.");
        } else {
            fail("Preparing the sandbox workspace timed out. Check filesystem "
                + "access, then use /reconnect.");
        }
        return false;
    }

    Timer {
        id: discoveryRetry

        interval: AiConfig.sandboxCheckRetryDelayMs
        repeat: false
        onTriggered: {
            root.beginStage("checking", AiConfig.sandboxCheckTimeoutMs);
            discovery.running = true;
        }
    }

    Process {
        id: discovery

        command: AiConfig.sbxCommand.concat(["ls", "-q"])
        stdout: StdioCollector { id: sandboxList }
        stderr: StdioCollector { id: discoveryError }
        onExited: function(exitCode) {
            if (!root.stageExited()) {
                return;
            }
            if (exitCode !== 0) {
                root.discoveryFailures++;
                if (root.discoveryFailures <= AiConfig.sandboxCheckRetryLimit) {
                    root.state = "retrying";
                    discoveryRetry.restart();
                    return;
                }
                const detail = discoveryError.text.trim().replace(/\s+/g, " ").slice(0, 180);
                root.fail((detail.length > 0 ? "sbx ls failed: " + detail
                    : "Could not list sbx sandboxes.") + " Use Reconnect to retry.");
                return;
            }
            const sandboxes = sandboxList.text.split(/\r?\n/)
                .map(name => name.trim()).filter(name => name.length > 0);
            if (sandboxes.indexOf(root.sandboxName) >= 0) {
                root.warmSandbox();
                return;
            }
            root.beginStage("preparing", AiConfig.sandboxWorkspaceTimeoutMs);
            resetWorkspace.running = true;
        }
    }

    Process {
        id: resetWorkspace

        command: ["rm", "-rf", "--", root.workspace]
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            if (!root.stageExited()) {
                return;
            }
            if (exitCode !== 0) {
                root.fail("Could not reset the private AI sandbox workspace.");
                return;
            }
            root.beginStage("preparing", AiConfig.sandboxWorkspaceTimeoutMs);
            prepareWorkspace.running = true;
        }
    }

    Process {
        id: prepareWorkspace

        command: ["install", "-d", "-m", "700", "--", root.workspace,
            AiConfig.sandboxOutputDirectoryForProject(root.projectId)]
        onExited: function(exitCode) {
            if (!root.stageExited()) {
                return;
            }
            if (exitCode !== 0) {
                root.fail("Could not create the private AI sandbox workspace.");
                return;
            }
            root.beginStage("creating", AiConfig.sandboxCreateTimeoutMs);
            createSandbox.running = true;
        }
    }

    Process {
        id: createSandbox

        command: AiConfig.sbxCommand.concat([
            "create", "codex", root.workspace, "--name", root.sandboxName, "--quiet"
        ])
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            if (!root.stageExited()) {
                return;
            }
            if (exitCode !== 0) {
                root.fail("Could not create the dedicated Codex sandbox. "
                    + "Run sbx diagnose, then use /reconnect.");
                return;
            }
            root.created();
            root.warmSandbox();
        }
    }

    Process {
        id: startSandbox

        // An attached idle session prevents sandboxd's 30-second auto-stop.
        command: AiConfig.sbxCommand.concat([
            "exec", "-i", root.sandboxName, "sh", "-c",
            "printf 'ready\\n'; exec cat >/dev/null"
        ])
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                if (data === "ready" && root.state === "starting" && !root.timedOut) {
                    deadline.stop();
                    root.state = "ready";
                    root.finished(true);
                }
            }
        }
        stderr: StdioCollector { id: startError }
        onExited: function(exitCode) {
            if (root.state === "idle") {
                if (root.restartRequested) {
                    root.restartRequested = false;
                    Qt.callLater(() => root.start());
                }
                return;
            }
            if (!root.stageExited()) {
                return;
            }
            const detail = startError.text.trim().replace(/\s+/g, " ").slice(0, 180);
            root.fail("Sandbox warm session exited (code " + exitCode + "). "
                + detail + " Use Reconnect to retry.");
        }
    }
}
