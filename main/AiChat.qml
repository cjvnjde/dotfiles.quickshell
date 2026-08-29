import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property bool shown: false
    property string connectionState: transport.state
    property string statusText: statusForState(connectionState)
    property string currentThreadId: ""
    property string currentTurnId: ""
    property string lastError: transport.lastError
    property bool isGenerating: false
    property bool submissionStarting: false
    property string selectedModel: ""
    property string selectedModelName: "Codex"
    property string selectedEffort: "default"
    property var availableModels: []
    property var supportedEfforts: []
    property var pendingRequests: ({})
    property var queuedSubmission: null
    property var currentTurnAttachments: []
    property var conversationHostFiles: []
    property string diagnosticText: ""
    property string resolvedSandboxName: ""
    property bool discoveringSandbox: false
    property bool captureRequested: false
    property bool recreatingSandbox: false
    property string currentTitle: "New conversation"
    readonly property bool conversationStarted: messageModel.count > 0
        || submissionStarting || isGenerating
    readonly property alias messages: messageModel
    readonly property alias pendingAttachments: attachmentModel
    readonly property bool attachmentsBusy: screenshot.state === "preparing"
        || screenshot.state === "selecting"
        || screenshot.state === "importing"
        || screenshot.state === "validating"
        || screenshot.state === "capturing"
        || screenshot.state === "copying"

    signal submissionAccepted()
    signal focusComposer()

    function statusForState(value) {
        if (discoveringSandbox) {
            return "Finding Codex sandbox…";
        }
        if (value === "connecting") {
            return "Starting sandbox…";
        }
        if (value === "initializing") {
            return "Connecting to Codex…";
        }
        if (value === "ready") {
            return "Ready";
        }
        if (value === "streaming") {
            return "Codex is responding…";
        }
        if (value === "error") {
            return "Backend unavailable";
        }
        return "Disconnected";
    }

    function titleCase(value) {
        const text = String(value || "");
        return text.length === 0 ? "" : text.charAt(0).toUpperCase() + text.slice(1);
    }

    function conciseModelName(value) {
        const name = String(value || "Codex").replace(/^GPT-/i, "");
        return name.replace(/-/g, " ");
    }

    function modelStatusText() {
        const effort = selectedEffort === "" || selectedEffort === "default"
            ? "Auto" : titleCase(selectedEffort);
        return conciseModelName(selectedModelName) + " " + effort;
    }

    function modelById(modelId) {
        const requested = String(modelId || "").toLowerCase();
        for (const model of availableModels) {
            if (String(model.id).toLowerCase() === requested
                    || String(model.displayName).toLowerCase() === requested) {
                return model;
            }
        }
        return null;
    }

    function chooseModel(modelId) {
        const model = modelById(modelId);
        if (model === null) {
            lastError = "Unknown model. Type /model to see available models.";
            return false;
        }
        selectedModel = model.id;
        selectedModelName = model.displayName;
        supportedEfforts = model.efforts;
        if (supportedEfforts.indexOf(selectedEffort) < 0) {
            selectedEffort = model.defaultEffort || "default";
        }
        lastError = "";
        return true;
    }

    function chooseEffort(effort) {
        const requested = String(effort || "").toLowerCase();
        if (supportedEfforts.indexOf(requested) < 0) {
            lastError = "Unsupported thinking level. Type /thinking to see available levels.";
            return false;
        }
        selectedEffort = requested;
        lastError = "";
        return true;
    }

    function updateModels(payload) {
        const source = payload && Array.isArray(payload.data) ? payload.data : [];
        const models = [];
        for (const entry of source) {
            if (!entry || entry.hidden === true) {
                continue;
            }
            const effortEntries = Array.isArray(entry.supportedReasoningEfforts)
                ? entry.supportedReasoningEfforts : [];
            const efforts = [];
            for (const effortEntry of effortEntries) {
                const effort = typeof effortEntry === "string"
                    ? effortEntry
                    : String(effortEntry.reasoningEffort || effortEntry.effort || "");
                if (effort.length > 0 && efforts.indexOf(effort) < 0) {
                    efforts.push(effort);
                }
            }
            const id = String(entry.id || entry.model || "");
            if (id.length === 0) {
                continue;
            }
            models.push({
                id: id,
                displayName: String(entry.displayName || entry.name || id),
                defaultEffort: String(entry.defaultReasoningEffort
                    || (efforts.length > 0 ? efforts[0] : "default")),
                efforts: efforts.length > 0 ? efforts : ["default"],
                isDefault: entry.isDefault === true
            });
        }
        availableModels = models;
        if (models.length === 0) {
            return;
        }
        let active = modelById(selectedModel);
        if (active === null) {
            active = models.find(model => model.isDefault) || models[0];
        }
        chooseModel(active.id);
    }

    function modelSettings(params) {
        if (selectedModel.length > 0) {
            params.model = selectedModel;
        }
        if (selectedEffort.length > 0 && selectedEffort !== "default") {
            params.effort = selectedEffort;
        }
        return params;
    }

    function commandItems(draft) {
        const value = String(draft || "").replace(/^\s+/, "");
        const lowered = value.toLowerCase();
        if (lowered.indexOf("/model") === 0
                && (lowered.length === 6 || lowered.charAt(6) === " ")) {
            const query = lowered.slice(6).trim();
            return availableModels.filter(model => query.length === 0
                    || model.id.toLowerCase().indexOf(query) >= 0
                    || model.displayName.toLowerCase().indexOf(query) >= 0)
                .map(model => ({
                    label: model.displayName,
                    detail: model.id === selectedModel ? "Current model" : model.id,
                    draft: "/model " + model.id,
                    immediate: true
                }));
        }
        if ((lowered.indexOf("/thinking") === 0
                    && (lowered.length === 9 || lowered.charAt(9) === " "))
                || (lowered.indexOf("/effort") === 0
                    && (lowered.length === 7 || lowered.charAt(7) === " "))) {
            const offset = lowered.indexOf("/thinking") === 0 ? 9 : 7;
            const query = lowered.slice(offset).trim();
            return supportedEfforts.filter(effort => query.length === 0
                    || effort.indexOf(query) >= 0)
                .map(effort => ({
                    label: titleCase(effort),
                    detail: effort === selectedEffort ? "Current thinking level" : "Thinking level",
                    draft: "/thinking " + effort,
                    immediate: true
                }));
        }

        const commands = [
            { label: "/ps", detail: "Capture a screen region", draft: "/ps", immediate: true },
            { label: "/model", detail: "Change model", draft: "/model ", immediate: false },
            { label: "/thinking", detail: "Change thinking level", draft: "/thinking ", immediate: false },
            { label: "/new", detail: "Start a new chat", draft: "/new", immediate: true },
            { label: "/reconnect", detail: "Reconnect the backend", draft: "/reconnect", immediate: true }
        ];
        return commands.filter(command => command.label.indexOf(lowered) === 0);
    }

    function executeSlashCommand(value) {
        const text = String(value || "").trim();
        if (text.charAt(0) !== "/") {
            return false;
        }
        const pieces = text.split(/\s+/);
        const command = pieces[0].toLowerCase();
        const argument = pieces.slice(1).join(" ");
        if (command === "/model" && argument.length === 0
                || (command === "/thinking" || command === "/effort")
                    && argument.length === 0) {
            return false;
        }
        if (command === "/ps" || command === "/screenshot") {
            captureRegion();
        } else if (command === "/model") {
            chooseModel(argument);
        } else if (command === "/thinking" || command === "/effort") {
            chooseEffort(argument);
        } else if (command === "/new") {
            newChat();
        } else if (command === "/reconnect") {
            reconnect();
        } else if (command === "/retry") {
            retryAttachment();
        } else if (command === "/discard") {
            discardFailedAttachment();
        } else {
            lastError = "Unknown command. Type / to see available commands.";
        }
        return true;
    }

    function safeAssistantMarkdown(value) {
        return String(value)
            .replace(/!\[/g, "\\![")
            .replace(/</g, "&lt;");
    }

    function open() {
        shown = true;
        if (AiConfig.backendAutoStart && connectionState === "disconnected") {
            startBackend();
        }
        Qt.callLater(() => focusComposer());
    }

    function startBackend() {
        if (resolvedSandboxName.length > 0) {
            transport.start();
            return;
        }
        if (!sandboxDiscovery.running) {
            discoveringSandbox = true;
            lastError = "";
            sandboxDiscovery.running = true;
        }
    }

    function createSandbox() {
        discoveringSandbox = true;
        resetSandboxWorkspace.command = [
            "rm", "-rf", "--", AiConfig.sandboxWorkspace
        ];
        resetSandboxWorkspace.running = true;
    }

    function recreateSandbox() {
        transport.stop();
        resolvedSandboxName = "";
        recreatingSandbox = true;
        discoveringSandbox = true;
        removeChatSandbox.command = ["sbx", "rm", AiConfig.sandboxName, "--force"];
        removeChatSandbox.running = true;
    }

    function close() {
        shown = false;
    }

    function toggle() {
        if (shown) {
            close();
        } else {
            open();
        }
    }

    function captureRegion() {
        if (attachmentsBusy) {
            return;
        }
        if (resolvedSandboxName.length === 0) {
            captureRequested = true;
            startBackend();
            return;
        }
        beginCapture();
    }

    function beginCapture() {
        captureRequested = false;
        shown = false;
        captureDelay.restart();
    }

    function localPath(fileUrl) {
        const value = decodeURIComponent(String(fileUrl || ""));
        return value.startsWith("file://") ? value.slice(7) : value;
    }

    function importImage(fileUrl) {
        const path = localPath(fileUrl);
        if (path.length > 0) {
            screenshot.importFile(path);
        }
    }

    function pasteClipboardImage() {
        screenshot.pasteClipboardImage();
    }

    function newChat() {
        if (attachmentsBusy) {
            shown = true;
            lastError = "Wait for the screenshot operation to finish or discard it.";
            return;
        }
        if (isGenerating) {
            stop();
        }
        overloadRetry.stop();
        overloadRetry.pending = null;
        pendingRequests = {};
        currentThreadId = "";
        currentTurnId = "";
        currentTitle = "New conversation";
        queuedSubmission = null;
        submissionStarting = false;
        captureRequested = false;
        clearConversationFiles();
        messageModel.clear();
        clearAttachments();
        screenshot.discard();
        lastError = "";
        focusComposer();
        recreateSandbox();
    }

    function clearAttachments() {
        for (let index = 0; index < attachmentModel.count; index++) {
            const attachment = attachmentModel.get(index);
            screenshot.removeHostFile(attachment.hostPath);
            screenshot.removeSandboxFile(attachment.sandboxPath);
        }
        attachmentModel.clear();
    }

    function clearConversationFiles() {
        for (let index = 0; index < conversationHostFiles.length; index++) {
            screenshot.removeHostFile(conversationHostFiles[index]);
        }
        conversationHostFiles = [];
        for (let index = 0; index < currentTurnAttachments.length; index++) {
            screenshot.removeSandboxFile(currentTurnAttachments[index].sandboxPath);
        }
        currentTurnAttachments = [];
    }

    function removeAttachment(index) {
        if (index < 0 || index >= attachmentModel.count) {
            return;
        }
        const attachment = attachmentModel.get(index);
        screenshot.removeHostFile(attachment.hostPath);
        screenshot.removeSandboxFile(attachment.sandboxPath);
        attachmentModel.remove(index);
    }

    function reconnect() {
        lastError = "";
        if (resolvedSandboxName.length === 0) {
            startBackend();
        } else {
            transport.reconnect();
        }
    }

    function findAttachment(token) {
        for (let index = 0; index < attachmentModel.count; index++) {
            if (attachmentModel.get(index).token === token) {
                return index;
            }
        }
        return -1;
    }

    function retryAttachment() {
        lastError = "";
        screenshot.retryCopy();
    }

    function discardFailedAttachment() {
        const index = findAttachment(screenshot.token);
        if (index >= 0) {
            attachmentModel.remove(index);
        }
        screenshot.discard();
        lastError = "";
    }

    function call(method, params, kind, context) {
        const requestId = transport.request(method, params);
        if (requestId < 0) {
            lastError = "The Codex backend is not connected.";
            submissionStarting = false;
            return -1;
        }
        const updated = Object.assign({}, pendingRequests);
        updated[requestId] = {
            method: method,
            params: params,
            kind: kind,
            context: context || {},
            retryCount: 0
        };
        pendingRequests = updated;
        return requestId;
    }

    function forgetRequest(requestId) {
        const updated = Object.assign({}, pendingRequests);
        delete updated[requestId];
        pendingRequests = updated;
    }

    function send(text) {
        const prompt = text.trim();
        if (submissionStarting || isGenerating || attachmentsBusy) {
            return;
        }
        if (prompt.length === 0 && attachmentModel.count === 0) {
            lastError = "Write a message or attach a screenshot first.";
            return;
        }
        if (!transport.ready) {
            lastError = "Codex is still connecting. Your draft has been preserved.";
            if (connectionState === "disconnected" || connectionState === "error") {
                startBackend();
            }
            return;
        }

        const attachments = [];
        for (let index = 0; index < attachmentModel.count; index++) {
            const attachment = attachmentModel.get(index);
            if (attachment.status !== "ready") {
                lastError = "Wait for the screenshot to finish copying, or remove it.";
                return;
            }
            attachments.push({
                token: attachment.token,
                hostPath: attachment.hostPath,
                sandboxPath: attachment.sandboxPath
            });
        }
        queuedSubmission = { text: prompt, attachments: attachments };
        submissionStarting = true;
        lastError = "";
        if (currentThreadId.length === 0) {
            const threadParams = {
                cwd: AiConfig.sandboxWorkingDirectory,
                approvalPolicy: "never",
                sandbox: "read-only"
            };
            if (selectedModel.length > 0) {
                threadParams.model = selectedModel;
            }
            call("thread/start", threadParams, "threadStart", {});
        } else {
            startQueuedTurn();
        }
    }

    function startQueuedTurn() {
        if (queuedSubmission === null || currentThreadId.length === 0) {
            submissionStarting = false;
            return;
        }

        const input = [];
        if (queuedSubmission.text.length > 0) {
            input.push({ type: "text", text: queuedSubmission.text });
        }
        for (const attachment of queuedSubmission.attachments) {
            input.push({ type: "localImage", path: attachment.sandboxPath });
        }
        call("turn/start", modelSettings({
            threadId: currentThreadId,
            input: input,
            cwd: AiConfig.sandboxWorkingDirectory,
            approvalPolicy: "never",
            sandboxPolicy: { type: "readOnly" }
        }), "turnStart", { submission: queuedSubmission });
    }

    function stop() {
        if (!isGenerating || currentThreadId.length === 0 || currentTurnId.length === 0) {
            return;
        }
        call("turn/interrupt", {
            threadId: currentThreadId,
            turnId: currentTurnId
        }, "interrupt", {});
    }

    function appendMessage(role, text, status, threadId, turnId, itemId, attachments) {
        const attachmentEntries = [];
        const paths = attachments || [];
        for (let index = 0; index < paths.length; index++) {
            attachmentEntries.push({ hostPath: String(paths[index]) });
        }
        messageModel.append({
            messageId: Date.now().toString(36) + "-" + messageModel.count,
            role: role,
            body: text,
            messageStatus: status,
            threadId: threadId || "",
            turnId: turnId || "",
            itemId: itemId || "",
            attachmentPaths: attachmentEntries,
            errorText: "",
            createdAt: new Date().toISOString()
        });
        return messageModel.count - 1;
    }

    function findAssistantMessage(itemId) {
        for (let index = messageModel.count - 1; index >= 0; index--) {
            const message = messageModel.get(index);
            if (message.role === "assistant" && message.itemId === itemId) {
                return index;
            }
        }
        return -1;
    }

    function handleResponse(requestId, succeeded, payload) {
        const pending = pendingRequests[requestId];
        if (pending === undefined) {
            return;
        }
        forgetRequest(requestId);

        if (!succeeded) {
            if (pending.kind === "modelList") {
                diagnosticText = "Codex did not provide a model catalog.";
                return;
            }
            if (Number(payload.code) === -32001 && pending.retryCount < 3) {
                overloadRetry.pending = pending;
                overloadRetry.interval = 500 + Math.floor(Math.random() * 350);
                overloadRetry.restart();
                return;
            }
            lastError = String(payload.message || "Codex rejected " + pending.method + ".");
            if (pending.kind === "initialize" || pending.kind === "accountRead") {
                transport.state = "error";
            } else if (pending.kind === "threadResume") {
                currentThreadId = "";
                transport.state = "ready";
                lastError = "The previous chat could not be resumed; the next message will start a new chat.";
            }
            submissionStarting = false;
            if (pending.kind === "turnStart") {
                queuedSubmission = pending.context.submission;
            }
            return;
        }

        if (pending.kind === "initialize") {
            transport.notify("initialized", {});
            call("account/read", { refreshToken: false }, "accountRead", {});
        } else if (pending.kind === "accountRead") {
            const account = payload ? payload.account : null;
            const requiresOpenaiAuth = payload && payload.requiresOpenaiAuth === true;
            if (requiresOpenaiAuth || (account && account.type === "apiKey")) {
                transport.state = "error";
                lastError = account && account.type === "apiKey"
                    ? "This chat requires subscription OAuth, not API-key billing. Run: sbx secret set openai --oauth"
                    : "Codex authentication is unavailable. Run: sbx secret set openai --oauth";
            } else {
                transport.reconnectAttempt = 0;
                call("model/list", {
                    limit: 100,
                    includeHidden: false
                }, "modelList", {});
                if (currentThreadId.length > 0) {
                    call("thread/resume", { threadId: currentThreadId }, "threadResume", {});
                } else {
                    transport.state = "ready";
                }
            }
        } else if (pending.kind === "modelList") {
            updateModels(payload);
        } else if (pending.kind === "threadResume") {
            const resumedThread = payload.thread || {};
            currentThreadId = String(resumedThread.id || currentThreadId);
            transport.state = "ready";
        } else if (pending.kind === "threadStart") {
            currentThreadId = String(payload.thread ? payload.thread.id : payload.threadId || "");
            if (currentThreadId.length === 0) {
                submissionStarting = false;
                lastError = "Codex did not return a thread ID.";
                return;
            }
            startQueuedTurn();
        } else if (pending.kind === "turnStart") {
            const turn = payload.turn || {};
            currentTurnId = String(turn.id || payload.turnId || "");
            const submission = pending.context.submission;
            if (messageModel.count === 0 && submission.text.length > 0) {
                currentTitle = submission.text.length > 48
                    ? submission.text.slice(0, 48) + "…" : submission.text;
            }
            currentTurnAttachments = submission.attachments;
            const submittedHostPaths = submission.attachments.map(item => item.hostPath);
            conversationHostFiles = conversationHostFiles.concat(submittedHostPaths);
            appendMessage("user", submission.text, "completed", currentThreadId,
                currentTurnId, "", submittedHostPaths);
            appendMessage("assistant", "", "streaming", currentThreadId,
                currentTurnId, "", []);
            queuedSubmission = null;
            submissionStarting = false;
            isGenerating = true;
            transport.state = "streaming";
            attachmentModel.clear();
            submissionAccepted();
        }
    }

    function handleNotification(method, params) {
        if (method === "turn/started") {
            const turn = params.turn || {};
            currentTurnId = String(turn.id || params.turnId || currentTurnId);
            return;
        }
        if (method === "item/agentMessage/delta") {
            const itemId = String(params.itemId || "");
            let index = findAssistantMessage(itemId);
            if (index < 0) {
                index = findAssistantMessage("");
                if (index >= 0) {
                    messageModel.setProperty(index, "itemId", itemId);
                } else {
                    index = appendMessage("assistant", "", "streaming", currentThreadId,
                        currentTurnId, itemId, []);
                }
            }
            messageModel.setProperty(index, "body", messageModel.get(index).body + String(params.delta || ""));
            return;
        }
        if (method === "item/completed") {
            const item = params.item || {};
            if (item.type !== "agentMessage") {
                return;
            }
            const itemId = String(item.id || params.itemId || "");
            let index = findAssistantMessage(itemId);
            if (index < 0) {
                index = findAssistantMessage("");
            }
            if (index >= 0) {
                if (item.text !== undefined) {
                    messageModel.setProperty(index, "body", String(item.text));
                }
                messageModel.setProperty(index, "messageStatus", "completed");
                messageModel.setProperty(index, "itemId", itemId);
            }
            return;
        }
        if (method === "error") {
            const eventError = params.error || {};
            const message = String(eventError.message || params.message
                || "The Codex turn failed.").slice(0, 600);
            lastError = message;
            for (let index = messageModel.count - 1; index >= 0; index--) {
                if (messageModel.get(index).role === "assistant"
                        && messageModel.get(index).messageStatus === "streaming") {
                    messageModel.setProperty(index, "errorText", message);
                    break;
                }
            }
            return;
        }
        if (method === "turn/completed") {
            const turn = params.turn || {};
            const status = String(turn.status || params.status || "completed");
            const turnError = turn.error || params.error || {};
            const failureMessage = status === "failed"
                ? String(turnError.message || "The Codex turn failed.").slice(0, 600)
                : "";
            if (failureMessage.length > 0) {
                lastError = failureMessage;
            }
            isGenerating = false;
            currentTurnId = "";
            transport.state = "ready";
            for (const attachment of currentTurnAttachments) {
                screenshot.removeSandboxFile(attachment.sandboxPath);
            }
            currentTurnAttachments = [];
            for (let index = messageModel.count - 1; index >= 0; index--) {
                if (messageModel.get(index).role === "assistant"
                        && messageModel.get(index).messageStatus === "streaming") {
                    messageModel.setProperty(index, "messageStatus",
                        status === "completed" ? "completed" : status);
                    if (failureMessage.length > 0) {
                        messageModel.setProperty(index, "errorText", failureMessage);
                    }
                    break;
                }
            }
        }
    }

    function declineServerRequest(requestId, method) {
        if (method === "item/permissions/requestApproval") {
            transport.reply(requestId, { permissions: [] });
            appendMessage("notice", "Blocked a permission request in chat-only mode.",
                "completed", currentThreadId, currentTurnId, "", []);
        } else if (method === "item/commandExecution/requestApproval"
                || method === "item/fileChange/requestApproval") {
            transport.reply(requestId, { decision: "decline" });
            appendMessage("notice", "Blocked an approval request in chat-only mode.",
                "completed", currentThreadId, currentTurnId, "", []);
        } else {
            transport.replyError(requestId, -32601, "Unsupported by this chat-only client");
        }
    }

    ListModel { id: messageModel }
    ListModel { id: attachmentModel }

    Process {
        id: sandboxDiscovery

        command: ["sbx", "ls", "-q"]
        stdout: StdioCollector { id: sandboxListOutput }
        stderr: StdioCollector { id: sandboxListError }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.discoveringSandbox = false;
                transport.state = "error";
                root.lastError = "Could not list sbx sandboxes: "
                    + sandboxListError.text.trim().slice(0, 180);
                root.captureRequested = false;
                root.shown = true;
                return;
            }
            const sandboxes = sandboxListOutput.text.split(/\r?\n/)
                .map(name => name.trim()).filter(name => name.length > 0);
            if (sandboxes.length === 0) {
                root.createSandbox();
                return;
            }
            if (sandboxes.indexOf(AiConfig.sandboxName) >= 0) {
                root.resolvedSandboxName = AiConfig.sandboxName;
                root.discoveringSandbox = false;
                if (root.captureRequested) {
                    root.beginCapture();
                }
                transport.start();
            } else {
                root.createSandbox();
            }
        }
    }

    Process {
        id: resetSandboxWorkspace

        stderr: StdioCollector { id: resetWorkspaceError }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.discoveringSandbox = false;
                transport.state = "error";
                root.lastError = "Could not reset the private AI sandbox workspace: "
                    + resetWorkspaceError.text.trim().slice(0, 180);
                return;
            }
            prepareSandboxWorkspace.command = [
                "install", "-d", "-m", "700", "--", AiConfig.sandboxWorkspace
            ];
            prepareSandboxWorkspace.running = true;
        }
    }

    Process {
        id: prepareSandboxWorkspace

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.discoveringSandbox = false;
                transport.state = "error";
                root.lastError = "Could not create the private AI sandbox workspace.";
                return;
            }
            createChatSandbox.command = [
                "sbx", "create", "codex", AiConfig.sandboxWorkspace,
                "--name", AiConfig.sandboxName, "--quiet"
            ];
            createChatSandbox.running = true;
        }
    }

    Process {
        id: createChatSandbox

        stdout: StdioCollector {}
        stderr: StdioCollector { id: createSandboxError }
        onExited: function(exitCode) {
            root.recreatingSandbox = false;
            root.discoveringSandbox = false;
            if (exitCode !== 0) {
                transport.state = "error";
                const diagnostic = createSandboxError.text.trim().slice(0, 600);
                root.lastError = "sbx create failed for " + AiConfig.sandboxName
                    + " using " + AiConfig.sandboxWorkspace + ": " + diagnostic;
                console.warn("AI sandbox creation failed:", diagnostic);
                root.captureRequested = false;
                root.shown = true;
                return;
            }
            root.resolvedSandboxName = AiConfig.sandboxName;
            root.diagnosticText = "Using dedicated sandbox " + root.resolvedSandboxName;
            if (root.captureRequested) {
                root.beginCapture();
            }
            transport.start();
        }
    }

    Process {
        id: removeChatSandbox

        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            // A missing dedicated sandbox is equivalent to an already-clean state.
            root.createSandbox();
        }
    }

    CodexAppServer {
        id: transport
        sandboxName: root.resolvedSandboxName

        onResponse: (requestId, succeeded, payload) => root.handleResponse(requestId, succeeded, payload)
        onNotification: (method, params) => root.handleNotification(method, params)
        onServerRequest: (requestId, method, params) => root.declineServerRequest(requestId, method)
        onDiagnostic: message => {
            root.diagnosticText = message;
            if (AiConfig.debug) {
                console.log("AI app-server diagnostic:", message);
            }
        }
        onStateChanged: {
            if (state === "initializing") {
                const updated = {};
                root.pendingRequests = updated;
                root.call("initialize", {
                    clientInfo: {
                        name: "quickshell_ai_chat",
                        title: "Quickshell AI Quick Chat",
                        version: "1.0.0"
                    },
                    capabilities: {}
                }, "initialize", {});
            } else if (state === "error") {
                overloadRetry.stop();
                overloadRetry.pending = null;
                if (root.submissionStarting) {
                    root.submissionStarting = false;
                    root.queuedSubmission = null;
                }
                if (root.isGenerating) {
                    root.isGenerating = false;
                    root.currentTurnId = "";
                    for (const attachment of root.currentTurnAttachments) {
                        screenshot.removeSandboxFile(attachment.sandboxPath);
                    }
                    root.currentTurnAttachments = [];
                    for (let index = root.messages.count - 1; index >= 0; index--) {
                        if (root.messages.get(index).role === "assistant"
                                && root.messages.get(index).messageStatus === "streaming") {
                            root.messages.setProperty(index, "messageStatus", "failed");
                            break;
                        }
                    }
                }
                if (transport.lastError.length > 0) {
                    root.lastError = transport.lastError;
                }
            }
        }
    }

    ScreenshotService {
        id: screenshot
        sandboxName: root.resolvedSandboxName

        onCaptured: (token, hostPath, sandboxPath) => {
            attachmentModel.append({
                token: token,
                hostPath: hostPath,
                sandboxPath: sandboxPath,
                status: "copying",
                errorText: ""
            });
            root.shown = true;
            Qt.callLater(() => root.focusComposer());
        }
        onReady: (token, hostPath, sandboxPath) => {
            const index = root.findAttachment(token);
            if (index >= 0) {
                attachmentModel.setProperty(index, "status", "ready");
                attachmentModel.setProperty(index, "errorText", "");
            }
            root.shown = true;
            Qt.callLater(() => root.focusComposer());
        }
        onCancelled: {
            root.shown = true;
            Qt.callLater(() => root.focusComposer());
        }
        onFailed: message => {
            root.lastError = message;
            const index = root.findAttachment(screenshot.token);
            if (index >= 0) {
                attachmentModel.setProperty(index, "status", "failed");
                attachmentModel.setProperty(index, "errorText", message);
            }
            root.shown = true;
            Qt.callLater(() => root.focusComposer());
        }
    }

    Timer {
        id: captureDelay
        interval: 180
        repeat: false
        onTriggered: screenshot.capture()
    }

    Timer {
        id: overloadRetry
        property var pending: null
        repeat: false
        onTriggered: {
            if (pending === null || !transport.ready) {
                root.lastError = "Codex is busy; retry when the backend is ready.";
                root.submissionStarting = false;
                return;
            }
            const requestId = transport.request(pending.method, pending.params);
            if (requestId < 0) {
                root.submissionStarting = false;
                return;
            }
            pending.retryCount++;
            const updated = Object.assign({}, root.pendingRequests);
            updated[requestId] = pending;
            root.pendingRequests = updated;
            pending = null;
        }
    }

    IpcHandler {
        target: "ai"

        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function screenshot(): void { root.captureRegion(); }
        function newChat(): void { root.newChat(); root.open(); }
        function attachScreenshot(path: string): void {
            screenshot.acceptCapture(path);
        }
        function screenshotCancelled(): void {
            screenshot.cancelCapture();
        }
        function screenshotFailed(message: string): void {
            screenshot.failCapture(message);
        }
        function attachImportedImage(path: string): void {
            screenshot.acceptImportedImage(path);
        }
        function attachmentCancelled(): void {
            screenshot.cancelImport();
        }
        function attachmentFailed(message: string): void {
            screenshot.failImport(message);
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: chatWindow

            required property var modelData
            readonly property var monitor: Hyprland.monitorFor(modelData)
            readonly property bool focusedScreen: monitor !== null && monitor.focused

            function acceptMenuItem(item) {
                composer.text = item.draft;
                composer.cursorPosition = composer.length;
                if (item.immediate && root.executeSlashCommand(composer.text)) {
                    composer.clear();
                } else {
                    composer.forceActiveFocus();
                }
            }

            function submitComposer() {
                if (root.isGenerating) {
                    root.stop();
                    return;
                }
                const draft = composer.text.trim();
                if (draft.charAt(0) === "/") {
                    const items = root.commandItems(composer.text);
                    for (const item of items) {
                        if (item.immediate && item.draft.trim() === draft
                                && root.executeSlashCommand(draft)) {
                            composer.clear();
                            return;
                        }
                    }
                    if (commandPalette.visible && items.length > 0) {
                        acceptMenuItem(items[Math.max(0, commandList.currentIndex)]);
                    } else if (root.executeSlashCommand(draft)) {
                        composer.clear();
                    }
                    return;
                }
                root.send(composer.text);
            }

            screen: modelData
            visible: root.shown && (focusedScreen || Quickshell.screens.length === 1)
            color: "transparent"
            exclusiveZone: 0
            aboveWindows: true

            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            onVisibleChanged: {
                if (visible) {
                    Qt.callLater(() => composer.forceActiveFocus());
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: root.close()
            }

            FileDialog {
                id: attachmentDialog
                title: "Attach an image"
                fileMode: FileDialog.OpenFile
                nameFilters: ["Images (*.png *.jpg *.jpeg *.webp)"]
                onAccepted: root.importImage(selectedFile)
            }

            Connections {
                target: root
                function onFocusComposer() {
                    if (chatWindow.visible) {
                        Qt.callLater(() => composer.forceActiveFocus());
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }

            Rectangle {
                id: card

                anchors.centerIn: parent
                width: Math.min(AiConfig.chatWidth, parent.width - 48)
                height: root.conversationStarted
                    ? Math.min(AiConfig.chatMaxHeight, parent.height * 0.78)
                    : Math.min(Math.max(126, composerStack.implicitHeight + 4),
                        parent.height - 24)
                radius: root.conversationStarted ? 26 : 36
                color: "#151515"
                border.width: 1
                border.color: "#545454"
                clip: true

                Behavior on height {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: mouse => mouse.accepted = true
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? 58 : 0
                        visible: root.conversationStarted

                        Rectangle {
                            width: 36
                            height: 36
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                            radius: 18
                            color: closeMouse.containsMouse ? "#272727" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: "#8d8d8d"
                                font.family: Theme.fontFamily
                                font.pixelSize: 25
                                font.weight: Font.Light
                            }
                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.close()
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 128
                            text: root.currentTitle
                            color: "#f1f1f1"
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                    }

                    ListView {
                        id: messageList
                        Layout.fillWidth: true
                        Layout.fillHeight: visible
                        Layout.preferredHeight: visible ? -1 : 0
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.topMargin: 16
                        Layout.bottomMargin: 16
                        visible: root.conversationStarted
                        model: root.messages
                        spacing: 18
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        property bool followNewest: true

                        onContentHeightChanged: {
                            if (followNewest) {
                                Qt.callLater(() => positionViewAtEnd());
                            }
                        }
                        onMovementEnded: followNewest = atYEnd

                        delegate: Item {
                            required property string role
                            required property string body
                            required property string messageStatus
                            required property string errorText
                            required property var attachmentPaths
                            readonly property int attachmentCount: attachmentPaths
                                && attachmentPaths.count !== undefined
                                    ? attachmentPaths.count
                                    : attachmentPaths && attachmentPaths.length
                                        ? attachmentPaths.length : 0
                            width: ListView.view.width
                            implicitHeight: messageBubble.implicitHeight

                            TextMetrics {
                                id: messageMetrics
                                text: body
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                            }

                            Rectangle {
                                id: messageBubble
                                width: role === "user"
                                    ? Math.min(parent.width * 0.82,
                                        Math.max(attachmentCount > 0 ? 320 : 88,
                                            messageMetrics.advanceWidth + 36))
                                    : parent.width
                                implicitHeight: messageContent.implicitHeight + 24
                                anchors.right: role === "user" ? parent.right : undefined
                                radius: role === "user" ? 20 : 0
                                color: role === "user" ? "#2b2b2b" : "transparent"

                                ColumnLayout {
                                    id: messageContent
                                    anchors { fill: parent; margins: 12 }
                                    spacing: 9

                                    Repeater {
                                        model: attachmentPaths
                                        Rectangle {
                                            required property string hostPath
                                            Layout.preferredWidth: Math.min(300, messageBubble.width - 24)
                                            Layout.preferredHeight: 150
                                            radius: 12
                                            color: "#202020"
                                            clip: true

                                            Image {
                                                anchors.fill: parent
                                                source: "file://" + hostPath
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                            }
                                        }
                                    }

                                    TextEdit {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: contentHeight
                                        visible: body.length > 0
                                        text: role === "assistant"
                                            ? root.safeAssistantMarkdown(body) : body
                                        textFormat: role === "assistant"
                                            ? Text.MarkdownText : Text.PlainText
                                        wrapMode: Text.Wrap
                                        color: role === "notice" ? "#b4b4b4" : "#eeeeee"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 14
                                        readOnly: true
                                        selectByMouse: role === "assistant"
                                    }

                                    Text {
                                        visible: messageStatus !== "completed"
                                            || errorText.length > 0
                                        text: messageStatus === "streaming" && body.length === 0
                                            ? "Thinking"
                                            : errorText.length > 0 ? errorText : messageStatus
                                        color: messageStatus === "failed" || errorText.length > 0
                                            ? Theme.red : "#777777"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: composerStack.implicitHeight
                            + (root.conversationStarted ? 16 : 4)

                        ColumnLayout {
                            id: composerStack
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                                leftMargin: root.conversationStarted ? 16 : 4
                                rightMargin: root.conversationStarted ? 16 : 4
                                bottomMargin: root.conversationStarted ? 16 : 4
                            }
                            spacing: 8

                            Rectangle {
                                id: commandPalette
                                Layout.fillWidth: true
                                Layout.preferredHeight: visible
                                    ? Math.min(224, commandList.contentHeight + 10) : 0
                                visible: composer.text.trim().charAt(0) === "/"
                                    && root.commandItems(composer.text).length > 0
                                radius: 18
                                color: "#222222"
                                border.width: 1
                                border.color: "#404040"
                                clip: true

                                ListView {
                                    id: commandList
                                    anchors { fill: parent; margins: 5 }
                                    model: root.commandItems(composer.text)
                                    currentIndex: 0
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index
                                        width: ListView.view.width
                                        height: 44
                                        radius: 13
                                        color: index === commandList.currentIndex
                                            || commandMouse.containsMouse ? "#303030" : "transparent"

                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 13; rightMargin: 13 }
                                            spacing: 12

                                            Text {
                                                text: modelData.label
                                                color: "#f0f0f0"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.detail
                                                color: "#7f7f7f"
                                                elide: Text.ElideRight
                                                horizontalAlignment: Text.AlignRight
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                            }
                                        }

                                        MouseArea {
                                            id: commandMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: commandList.currentIndex = index
                                            onClicked: chatWindow.acceptMenuItem(modelData)
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: composerFrame
                                Layout.fillWidth: true
                                Layout.preferredHeight: composerInner.implicitHeight
                                    + (root.conversationStarted ? 16 : 8)
                                radius: root.conversationStarted ? 24 : 30
                                color: root.conversationStarted ? "#282828" : "transparent"

                                ColumnLayout {
                                    id: composerInner
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: parent.top
                                        margins: root.conversationStarted ? 8 : 4
                                    }
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        visible: root.pendingAttachments.count > 0
                                        spacing: 8

                                        Repeater {
                                            model: root.pendingAttachments
                                            Rectangle {
                                                required property string hostPath
                                                required property int index
                                                Layout.preferredWidth: 112
                                                Layout.preferredHeight: 72
                                                radius: 12
                                                color: "#1c1c1c"
                                                clip: true

                                                Image {
                                                    anchors { fill: parent; margins: 3 }
                                                    source: "file://" + hostPath
                                                    fillMode: Image.PreserveAspectFit
                                                }
                                                Rectangle {
                                                    width: 24
                                                    height: 24
                                                    anchors { top: parent.top; right: parent.right; margins: 4 }
                                                    radius: 12
                                                    color: "#d8d8d8"

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "×"
                                                        color: "#171717"
                                                        font.pixelSize: 17
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: root.removeAttachment(index)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Math.max(
                                            root.conversationStarted ? 64 : 72,
                                            Math.min(132, composer.contentHeight + 28))

                                        Flickable {
                                            anchors {
                                                fill: parent
                                                leftMargin: root.conversationStarted ? 10 : 8
                                                rightMargin: root.conversationStarted ? 10 : 8
                                                topMargin: root.conversationStarted ? 10 : 12
                                                bottomMargin: root.conversationStarted ? 8 : 10
                                            }
                                            contentWidth: width
                                            contentHeight: composer.contentHeight
                                            clip: true

                                            TextEdit {
                                                id: composer
                                                width: parent.width
                                                color: "#eeeeee"
                                                selectionColor: "#515151"
                                                selectedTextColor: "#ffffff"
                                                wrapMode: TextEdit.Wrap
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 15

                                                onTextChanged: commandList.currentIndex = 0

                                                Text {
                                                    visible: composer.text.length === 0
                                                    text: root.conversationStarted
                                                        ? "Work with Codex" : "Ask Codex anything locally"
                                                    color: "#686868"
                                                    font: composer.font
                                                }

                                                Keys.onPressed: event => {
                                                    if (event.matches(StandardKey.Paste)) {
                                                        root.pasteClipboardImage();
                                                        event.accepted = false;
                                                        return;
                                                    }
                                                    if (event.key === Qt.Key_Escape) {
                                                        root.close();
                                                        event.accepted = true;
                                                    } else if (commandPalette.visible
                                                            && event.key === Qt.Key_Up) {
                                                        commandList.currentIndex = Math.max(0,
                                                            commandList.currentIndex - 1);
                                                        event.accepted = true;
                                                    } else if (commandPalette.visible
                                                            && event.key === Qt.Key_Down) {
                                                        commandList.currentIndex = Math.min(
                                                            commandList.count - 1,
                                                            commandList.currentIndex + 1);
                                                        event.accepted = true;
                                                    } else if ((event.key === Qt.Key_Return
                                                                || event.key === Qt.Key_Enter)
                                                            && !(event.modifiers & Qt.ShiftModifier)) {
                                                        chatWindow.submitComposer();
                                                        event.accepted = true;
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        Layout.leftMargin: root.conversationStarted ? 8 : 5
                                        Layout.rightMargin: 0
                                        spacing: 9

                                        PlusButton {
                                            enabled: !root.attachmentsBusy && !root.isGenerating
                                            onClicked: attachmentDialog.open()
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: root.lastError.length > 0
                                                || root.attachmentsBusy
                                            text: root.attachmentsBusy
                                                ? "Adding image…"
                                                : screenshot.state === "failed"
                                                    ? root.lastError
                                                        + (screenshot.failureStage === "copy"
                                                            ? "  /retry  /discard" : "  /discard")
                                                    : root.lastError
                                            color: root.lastError.length > 0
                                                ? Theme.red : "#858585"
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                        }

                                        Item {
                                            Layout.fillWidth: root.lastError.length === 0
                                                && !root.attachmentsBusy
                                        }

                                        Text {
                                            text: root.modelStatusText()
                                            color: "#d6d6d6"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                        }

                                        ActionButton {
                                            stopMode: root.isGenerating
                                            enabled: root.isGenerating || (!root.submissionStarting
                                                && !root.attachmentsBusy
                                                && (composer.text.trim().length > 0
                                                    || root.pendingAttachments.count > 0))
                                            onClicked: chatWindow.submitComposer()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Connections {
                target: root
                function onSubmissionAccepted() { composer.text = ""; }
            }
        }
    }

    component PlusButton: Rectangle {
        id: plusButton
        signal clicked()

        implicitWidth: 34
        implicitHeight: 34
        radius: 17
        color: plusMouse.containsMouse ? "#363636" : "transparent"
        opacity: enabled ? 1 : 0.38

        Canvas {
            anchors.fill: parent
            onPaint: {
                const context = getContext("2d");
                context.clearRect(0, 0, width, height);
                context.strokeStyle = "#ededed";
                context.lineWidth = 1.8;
                context.lineCap = "round";
                context.beginPath();
                context.moveTo(17, 8);
                context.lineTo(17, 26);
                context.moveTo(8, 17);
                context.lineTo(26, 17);
                context.stroke();
            }
        }

        MouseArea {
            id: plusMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: plusButton.enabled
            onClicked: plusButton.clicked()
        }
    }

    component ActionButton: Rectangle {
        id: actionButton
        property bool stopMode: false
        signal clicked()

        implicitWidth: 32
        implicitHeight: 32
        radius: 16
        color: stopMode ? "#f4f4f4"
            : actionMouse.containsMouse && enabled ? "#bdbdbd" : "#9a9a9a"
        opacity: enabled ? 1 : 0.42

        Canvas {
            anchors.fill: parent
            visible: !actionButton.stopMode
            onPaint: {
                const context = getContext("2d");
                context.clearRect(0, 0, width, height);
                context.strokeStyle = "#171717";
                context.lineWidth = 2;
                context.lineCap = "round";
                context.lineJoin = "round";
                context.beginPath();
                context.moveTo(10, 16);
                context.lineTo(16, 10);
                context.lineTo(22, 16);
                context.moveTo(16, 10);
                context.lineTo(16, 23);
                context.stroke();
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 10
            height: 10
            radius: 2
            visible: actionButton.stopMode
            color: "#101010"
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: actionButton.enabled
            onClicked: actionButton.clicked()
        }
    }
}
