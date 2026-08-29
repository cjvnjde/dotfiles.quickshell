import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string state: "idle"
    property string sandboxName: ""
    property string lastError: ""
    property string token: ""
    property string hostPath: ""
    property string sandboxPath: ""
    property string failureStage: ""
    property bool startupCleanupComplete: false
    property bool captureAfterCleanup: false
    property var pendingImport: null
    property string sourceKind: ""
    readonly property string runtimeDirectory: {
        const runtimeRoot = Quickshell.env("XDG_RUNTIME_DIR");
        return runtimeRoot.length > 0 ? runtimeRoot + "/quickshell-ai" : "";
    }

    signal captured(string token, string hostPath, string sandboxPath)
    signal ready(string token, string hostPath, string sandboxPath)
    signal cancelled()
    signal failed(string message)

    function managedHostFilename(path) {
        if (runtimeDirectory.length === 0) {
            return "";
        }
        const prefix = runtimeDirectory + "/";
        if (!path.startsWith(prefix)) {
            return "";
        }
        const filename = path.slice(prefix.length);
        return /^(capture-[A-Za-z0-9]{12}\.png|attachment-[A-Za-z0-9]{12}\.(png|jpe?g|webp))$/
            .test(filename) ? filename : "";
    }

    function managedCaptureFilename(path) {
        const filename = managedHostFilename(path);
        return /^capture-[A-Za-z0-9]{12}\.png$/.test(filename) ? filename : "";
    }

    function managedImportedFilename(path) {
        const filename = managedHostFilename(path);
        return /^attachment-[A-Za-z0-9]{12}\.(png|jpe?g|webp)$/.test(filename)
            ? filename : "";
    }

    function managedSandboxFilename(path) {
        const prefix = AiConfig.sandboxAttachmentDirectory + "/";
        if (!path.startsWith(prefix)) {
            return "";
        }
        const filename = path.slice(prefix.length);
        return /^(capture-[A-Za-z0-9]{12}\.png|attachment-[A-Za-z0-9]{12}\.(png|jpe?g|webp))$/
            .test(filename) ? filename : "";
    }

    function resetOperation() {
        token = "";
        hostPath = "";
        sandboxPath = "";
        failureStage = "";
        sourceKind = "";
    }

    function capture() {
        if (!startupCleanupComplete) {
            captureAfterCleanup = true;
            return;
        }
        if (state !== "idle" && state !== "ready") {
            return;
        }

        resetOperation();
        lastError = "";
        state = "selecting";
        Quickshell.execDetached({
            command: ["bash", Quickshell.shellPath("AiCaptureRegion.sh")]
        });
    }

    function importFile(path) {
        queueImport({ mode: "file", path: String(path || "") });
    }

    function pasteClipboardImage() {
        queueImport({ mode: "clipboard", path: "" });
    }

    function queueImport(request) {
        if (state !== "idle" && state !== "ready") {
            return;
        }
        if (!startupCleanupComplete || sandboxName.length === 0) {
            pendingImport = request;
            return;
        }
        startImport(request);
    }

    function startImport(request) {
        pendingImport = null;
        resetOperation();
        sourceKind = "attachment";
        lastError = "";
        state = "importing";
        const command = [
            "bash", Quickshell.shellPath("AiAttachImage.sh"), request.mode
        ];
        if (request.mode === "file") {
            command.push(request.path);
        }
        Quickshell.execDetached({ command: command });
    }

    function startPendingImport() {
        if (pendingImport !== null && startupCleanupComplete
                && sandboxName.length > 0
                && (state === "idle" || state === "ready")) {
            startImport(pendingImport);
        }
    }

    function acceptCapture(path) {
        if (state !== "selecting") {
            removeHostFile(path);
            return;
        }
        const filename = managedCaptureFilename(path);
        if (filename.length === 0) {
            fail("Screenshot helper returned an invalid image path.", "capture");
            return;
        }
        sourceKind = "screenshot";
        hostPath = path;
        token = filename.slice(0, filename.lastIndexOf("."));
        sandboxPath = AiConfig.sandboxAttachmentDirectory + "/" + filename;
        state = "validating";
        validateCapture.command = [
            "file", "--brief", "--mime-type", "--no-dereference", "--", hostPath
        ];
        validateCapture.running = true;
    }

    function acceptImportedImage(path) {
        if (state !== "importing") {
            removeHostFile(path);
            return;
        }
        const filename = managedImportedFilename(path);
        if (filename.length === 0) {
            fail("Attachment helper returned an invalid image path.", "attachment");
            return;
        }
        hostPath = path;
        token = filename.slice(0, filename.lastIndexOf("."));
        sandboxPath = AiConfig.sandboxAttachmentDirectory + "/" + filename;
        state = "validating";
        validateCapture.command = [
            "file", "--brief", "--mime-type", "--no-dereference", "--", hostPath
        ];
        validateCapture.running = true;
    }

    function beginCopy() {
        state = "copying";
        captured(token, hostPath, sandboxPath);
        prepareSandbox.command = [
            "sbx", "exec", sandboxName,
            "mkdir", "-p", "-m", "700", AiConfig.sandboxAttachmentDirectory
        ];
        prepareSandbox.running = true;
    }

    function cancelCapture() {
        if (state !== "selecting") {
            return;
        }
        resetOperation();
        state = "idle";
        cancelled();
    }

    function cancelImport() {
        if (state !== "importing") {
            return;
        }
        resetOperation();
        state = "idle";
        cancelled();
    }

    function failCapture(message) {
        if (state !== "selecting" && sourceKind !== "screenshot") {
            return;
        }
        fail(String(message).slice(0, 240), "capture");
    }

    function failImport(message) {
        if (state !== "importing" && sourceKind !== "attachment") {
            return;
        }
        fail(String(message).slice(0, 240), "attachment");
    }

    function fail(message, stage) {
        state = "failed";
        lastError = message;
        failureStage = stage || "capture";
        console.warn("AI attachment " + failureStage + " failed:", message);
        failed(message);
    }

    function retryCopy() {
        if (state !== "failed" || failureStage !== "copy") {
            return;
        }
        state = "copying";
        prepareSandbox.running = true;
    }

    function discard() {
        const discardedHostPath = hostPath;
        const discardedSandboxPath = sandboxPath;
        resetOperation();
        state = "idle";
        lastError = "";
        removeHostFile(discardedHostPath);
        removeSandboxFile(discardedSandboxPath);
    }

    function removeHostFile(path) {
        if (managedHostFilename(path).length === 0) {
            return;
        }
        Quickshell.execDetached({ command: ["rm", "-f", "--", path] });
    }

    function removeSandboxFile(path) {
        if (sandboxName.length === 0 || managedSandboxFilename(path).length === 0) {
            return;
        }
        Quickshell.execDetached({
            command: ["sbx", "exec", root.sandboxName, "rm", "-f", "--", path]
        });
    }

    Process {
        id: validateCapture
        stdout: StdioCollector { id: validatedCaptureOutput }
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            const mimeType = validatedCaptureOutput.text.trim();
            const supported = mimeType === "image/png" || mimeType === "image/jpeg"
                || mimeType === "image/webp";
            if (exitCode !== 0 || !supported) {
                root.fail("The selected attachment is not a supported image.",
                    root.sourceKind === "screenshot" ? "capture" : "attachment");
                return;
            }
            root.beginCopy();
        }
    }

    Process {
        id: prepareSandbox
        stdout: StdioCollector {}
        stderr: StdioCollector { id: prepareSandboxError }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.fail("Could not prepare the sandbox attachment directory: "
                    + prepareSandboxError.text.trim().slice(0, 160), "copy");
                return;
            }
            copyToSandbox.command = [
                "sbx", "cp", root.hostPath,
                root.sandboxName + ":" + root.sandboxPath
            ];
            copyToSandbox.running = true;
        }
    }

    Process {
        id: copyToSandbox
        stdout: StdioCollector {}
        stderr: StdioCollector { id: copyError }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.fail("sbx cp failed: " + copyError.text.trim().slice(0, 180), "copy");
                return;
            }
            root.state = "ready";
            root.failureStage = "";
            root.ready(root.token, root.hostPath, root.sandboxPath);
        }
    }

    Process {
        id: cleanupAbandonedHostFiles
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: {
            root.startupCleanupComplete = true;
            if (root.captureAfterCleanup) {
                root.captureAfterCleanup = false;
                root.capture();
            } else {
                root.startPendingImport();
            }
        }
    }

    Component.onCompleted: {
        if (runtimeDirectory.length === 0) {
            startupCleanupComplete = true;
            return;
        }
        cleanupAbandonedHostFiles.command = [
            "find", runtimeDirectory, "-maxdepth", "1", "-type", "f", "(",
            "-name", "capture-????????????.png", "-o",
            "-name", "attachment-????????????.png", "-o",
            "-name", "attachment-????????????.jpg", "-o",
            "-name", "attachment-????????????.jpeg", "-o",
            "-name", "attachment-????????????.webp", ")", "-delete"
        ];
        cleanupAbandonedHostFiles.running = true;
    }

    onSandboxNameChanged: startPendingImport()

}
