import QtQuick
import Quickshell
import Quickshell.Io
import ".."

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
    property string attachmentKind: ""
    property string displayName: ""
    readonly property string runtimeDirectory: {
        const runtimeRoot = Quickshell.env("XDG_RUNTIME_DIR");
        return runtimeRoot.length > 0 ? runtimeRoot + "/quickshell-ai" : "";
    }

    signal captured(string token, string hostPath, string sandboxPath,
        string attachmentKind, string displayName)
    signal ready(string token, string hostPath, string sandboxPath,
        string attachmentKind, string displayName)
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
        return /^(capture-[A-Za-z0-9]{12}\.png|attachment-[A-Za-z0-9]{12}\.(png|jpe?g|webp|txt))$/
            .test(filename) ? filename : "";
    }

    function managedCaptureFilename(path) {
        const filename = managedHostFilename(path);
        return /^capture-[A-Za-z0-9]{12}\.png$/.test(filename) ? filename : "";
    }

    function managedImportedFilename(path) {
        const filename = managedHostFilename(path);
        return /^attachment-[A-Za-z0-9]{12}\.(png|jpe?g|webp|txt)$/.test(filename)
            ? filename : "";
    }

    function managedSandboxFilename(path) {
        const prefix = AiConfig.sandboxAttachmentDirectory + "/";
        if (!path.startsWith(prefix)) {
            return "";
        }
        const filename = path.slice(prefix.length);
        return /^(capture-[A-Za-z0-9]{12}\.png|attachment-[A-Za-z0-9]{12}\.(png|jpe?g|webp|txt))$/
            .test(filename) ? filename : "";
    }

    function resetOperation() {
        token = "";
        hostPath = "";
        sandboxPath = "";
        failureStage = "";
        sourceKind = "";
        attachmentKind = "";
        displayName = "";
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
            command: ["bash", Quickshell.shellPath("ai-chat/AiCaptureRegion.sh")]
        });
    }

    function pickFile() {
        queueImport({ mode: "picker" });
    }

    function pasteClipboardImage() {
        queueImport({ mode: "clipboard" });
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
            "bash", Quickshell.shellPath("ai-chat/AiAttachFile.sh"), request.mode
        ];
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
        attachmentKind = "image";
        displayName = "Screenshot";
        hostPath = path;
        token = filename.slice(0, filename.lastIndexOf("."));
        sandboxPath = AiConfig.sandboxAttachmentDirectory + "/" + filename;
        state = "validating";
        validateCapture.command = [
            "file", "--brief", "--mime", "--no-dereference", "--", hostPath
        ];
        validateCapture.running = true;
    }

    function acceptImportedFile(path, kind, name) {
        if (state !== "importing") {
            removeHostFile(path);
            return;
        }
        const filename = managedImportedFilename(path);
        const normalizedKind = kind === "text" ? "text" : "image";
        const kindMatchesPath = normalizedKind === "text"
            ? filename.endsWith(".txt") : !filename.endsWith(".txt");
        if (filename.length === 0 || !kindMatchesPath) {
            fail("Attachment helper returned invalid file metadata.", "attachment");
            return;
        }
        attachmentKind = normalizedKind;
        displayName = String(name || (normalizedKind === "text" ? "Text file" : "Image"))
            .replace(/[\r\n\t]/g, " ").slice(0, 120);
        hostPath = path;
        token = filename.slice(0, filename.lastIndexOf("."));
        sandboxPath = AiConfig.sandboxAttachmentDirectory + "/" + filename;
        state = "validating";
        validateCapture.command = [
            "file", "--brief", "--mime", "--no-dereference", "--", hostPath
        ];
        validateCapture.running = true;
    }

    function beginCopy() {
        state = "copying";
        captured(token, hostPath, sandboxPath, attachmentKind, displayName);
        prepareSandbox.command = AiConfig.sbxCommand.concat([
            "exec", sandboxName, "mkdir", "-p", "-m", "700",
            AiConfig.sandboxAttachmentDirectory
        ]);
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
            command: AiConfig.sbxCommand.concat([
                "exec", root.sandboxName, "rm", "-f", "--", path
            ])
        });
    }

    Process {
        id: validateCapture
        stdout: StdioCollector { id: validatedCaptureOutput }
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            const mime = validatedCaptureOutput.text.trim();
            const mimeType = mime.split(";")[0].trim();
            const charsetMatch = mime.match(/charset=([^;\s]+)/);
            const encoding = charsetMatch ? charsetMatch[1] : "";
            const supportedImage = mimeType === "image/png" || mimeType === "image/jpeg"
                || mimeType === "image/webp";
            const supportedText = mimeType === "application/x-empty"
                || (encoding.length > 0 && encoding !== "binary");
            const supported = root.attachmentKind === "image"
                ? supportedImage : root.attachmentKind === "text" && supportedText;
            if (exitCode !== 0 || !supported) {
                root.fail("The selected attachment is not a supported image or text file.",
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
            copyToSandbox.command = AiConfig.sbxCommand.concat([
                "cp", root.hostPath, root.sandboxName + ":" + root.sandboxPath
            ]);
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
            root.ready(root.token, root.hostPath, root.sandboxPath,
                root.attachmentKind, root.displayName);
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
            "-name", "attachment-????????????.webp", "-o",
            "-name", "attachment-????????????.txt", ")", "-delete"
        ];
        cleanupAbandonedHostFiles.running = true;
    }

    onSandboxNameChanged: startPendingImport()

}
