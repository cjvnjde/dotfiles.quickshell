import QtQuick
import Quickshell
import Quickshell.Io
import "AiChatLogic.js" as AiChatLogic

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
    property string sandboxSetupStage: ""
    property bool sandboxSetupTimedOut: false
    readonly property bool sandboxSetupRunning: sandboxDiscovery.running
        || resetSandboxWorkspace.running || prepareSandboxWorkspace.running
        || createChatSandbox.running
    property bool captureRequested: false
    property int conversationGeneration: 0
    property var pendingThreadDeletes: []
    property string deletingThreadId: ""
    property string currentTitle: "New conversation"
    property bool codexAuthorized: false
    property bool syncingChatKit: false
    property bool codexUpdating: false
    property bool codexUpdateRequested: false
    property bool rebuildingSandbox: false
    property bool rebuildRequested: false
    property string maintenanceNotice: ""
    property string pendingMaintenanceNotice: ""
    readonly property bool maintenanceStatusVisible: rebuildingSandbox
        || codexUpdating || syncingChatKit || maintenanceNotice.length > 0
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
    readonly property string attachmentState: screenshot.state
    readonly property string attachmentFailureStage: screenshot.failureStage

    signal submissionAccepted()
    signal focusComposer()

    function statusForState(value) {
        if (rebuildingSandbox) {
            return "Rebuilding Codex sandbox…";
        }
        if (codexUpdating) {
            return "Updating Codex…";
        }
        if (syncingChatKit) {
            return "Loading AI chat kit…";
        }
        if (sandboxSetupStage === "checking") {
            return "Checking Codex sandbox…";
        }
        if (sandboxSetupStage === "preparing") {
            return "Preparing Codex sandbox…";
        }
        if (sandboxSetupStage === "creating") {
            return "Creating Codex sandbox…";
        }
        if (discoveringSandbox) {
            return "Setting up Codex sandbox…";
        }
        if (value === "connecting") {
            return "Starting sandbox…";
        }
        if (value === "initializing") {
            return "Connecting to Codex…";
        }
        if (value === "ready") {
            return maintenanceNotice.length > 0 ? maintenanceNotice : "Ready";
        }
        if (value === "streaming") {
            return "Codex is responding…";
        }
        if (value === "error") {
            return "Backend unavailable";
        }
        return "Disconnected";
    }

    function chooseModel(modelId) {
        const model = AiChatLogic.modelById(availableModels, modelId);
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
        const models = AiChatLogic.modelsFromPayload(payload);
        availableModels = models;
        if (models.length === 0) {
            return;
        }
        let active = AiChatLogic.modelById(models, selectedModel);
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

        switch (command) {
        case "/file":
            pickFile();
            break;
        case "/ps":
        case "/screenshot":
            captureRegion();
            break;
        case "/copy":
            copyChat();
            break;
        case "/model":
            chooseModel(argument);
            break;
        case "/thinking":
        case "/effort":
            chooseEffort(argument);
            break;
        case "/new":
            newChat();
            break;
        case "/reconnect":
            reconnect();
            break;
        case "/update":
            requestCodexUpdate();
            break;
        case "/rebuild":
            requestSandboxRebuild();
            break;
        case "/retry":
            retryAttachment();
            break;
        case "/discard":
            discardFailedAttachment();
            break;
        default:
            lastError = "Unknown command. Type / to see available commands.";
        }
        return true;
    }

    function copyText(value) {
        const text = String(value || "");
        if (text.length === 0) {
            return false;
        }
        clipboardBuffer.text = text;
        clipboardBuffer.selectAll();
        clipboardBuffer.copy();
        clipboardBuffer.deselect();
        return true;
    }

    function chatTranscript() {
        const sections = [];
        for (let index = 0; index < messageModel.count; index++) {
            const message = messageModel.get(index);
            if ((message.role !== "user" && message.role !== "assistant")
                    || message.body.trim().length === 0) {
                continue;
            }
            const label = message.role === "user" ? "You" : "AI";
            sections.push(label + ":\n" + message.body.trim());
        }
        return sections.join("\n\n");
    }

    function copyChat() {
        if (!copyText(chatTranscript())) {
            lastError = "There is no conversation to copy yet.";
            return false;
        }
        lastError = "";
        return true;
    }

    function openLink(value) {
        const link = String(value || "");
        if (/^(https?:|mailto:)/i.test(link)) {
            Qt.openUrlExternally(link);
            return;
        }
        lastError = "Only web and email links can be opened from AI answers.";
    }

    function findActivity(itemId) {
        const requested = String(itemId || "");
        for (let index = messageModel.count - 1; index >= 0; index--) {
            const message = messageModel.get(index);
            if (message.role === "activity" && message.itemId === requested) {
                return index;
            }
        }
        return -1;
    }

    function removeTurnPlaceholder() {
        const index = findActivity("turn:" + currentTurnId);
        if (index >= 0) {
            messageModel.remove(index);
        }
    }

    function appendTurnPlaceholder() {
        const index = appendMessage("activity", "", "streaming", currentThreadId,
            currentTurnId, "turn:" + currentTurnId, []);
        messageModel.setProperty(index, "activityType", "turn");
        messageModel.setProperty(index, "activityTitle", "Thinking");
    }

    function appendActivity(item, fallbackStatus) {
        const itemId = String(item && item.id || "");
        if (itemId.length === 0) {
            return -1;
        }
        let index = findActivity(itemId);
        const status = AiChatLogic.normalizedActivityStatus(
            item.status, fallbackStatus);
        if (index < 0) {
            index = appendMessage("activity", AiChatLogic.activityBody(item), status,
                currentThreadId, currentTurnId, itemId, []);
        } else {
            const body = AiChatLogic.activityBody(item);
            if (body.length > 0 || messageModel.get(index).body.length === 0) {
                messageModel.setProperty(index, "body", body);
            }
            messageModel.setProperty(index, "messageStatus", status);
        }
        messageModel.setProperty(index, "activityType", String(item.type || "activity"));
        messageModel.setProperty(index, "activityTitle",
            AiChatLogic.activityTitle(item));
        const output = AiChatLogic.activityOutput(item);
        if (output.length > 0) {
            messageModel.setProperty(index, "activityOutput", output);
        }
        return index;
    }

    function appendActivityText(itemId, delta, output) {
        const index = findActivity(itemId);
        if (index < 0) {
            return;
        }
        const role = output ? "activityOutput" : "body";
        const current = String(messageModel.get(index)[role] || "");
        const next = current + String(delta || "");
        const limit = 12000;
        messageModel.setProperty(index, role, next.length > limit
            ? "…\n" + next.slice(next.length - limit) : next);
    }

    function beginSandboxSetupStage(stage, timeoutMs) {
        sandboxSetupStage = stage;
        sandboxSetupTimeout.interval = timeoutMs;
        sandboxSetupTimeout.restart();
    }

    function finishSandboxSetup() {
        sandboxSetupTimeout.stop();
        sandboxSetupStage = "";
        sandboxSetupTimedOut = false;
        discoveringSandbox = false;
    }

    function failSandboxSetup(message) {
        sandboxSetupTimeout.stop();
        sandboxSetupStage = "";
        discoveringSandbox = false;
        captureRequested = false;
        rebuildRequested = false;
        codexUpdateRequested = false;
        pendingMaintenanceNotice = "";
        transport.state = "error";
        lastError = message;
        shown = true;
    }

    function stopSandboxSetupProcess() {
        if (sandboxDiscovery.running) {
            sandboxDiscovery.signal(9);
        }
        if (resetSandboxWorkspace.running) {
            resetSandboxWorkspace.signal(9);
        }
        if (prepareSandboxWorkspace.running) {
            prepareSandboxWorkspace.signal(9);
        }
        if (createChatSandbox.running) {
            createChatSandbox.signal(9);
        }
    }

    function sandboxSetupTimeoutMessage(stage) {
        if (stage === "checking") {
            return "sbx ls timed out. Run sbx ls in a terminal, resolve Docker "
                + "sign-in or sandboxd, then use /reconnect.";
        }
        if (stage === "creating") {
            return "sbx create timed out. Run sbx diagnose in a terminal, "
                + "then use /reconnect.";
        }
        return "Preparing the sandbox workspace timed out. Check filesystem "
            + "access, then use /reconnect.";
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
            continueBackendStartup();
            return;
        }
        if (sandboxSetupStage.length > 0 || sandboxSetupRunning
                || rebuildingSandbox || codexUpdating || syncingChatKit) {
            return;
        }

        sandboxSetupTimedOut = false;
        discoveringSandbox = true;
        lastError = "";
        beginSandboxSetupStage("checking", AiConfig.sandboxCheckTimeoutMs);
        sandboxDiscovery.running = true;
    }

    function createSandbox() {
        discoveringSandbox = true;
        beginSandboxSetupStage("preparing", AiConfig.sandboxWorkspaceTimeoutMs);
        resetSandboxWorkspace.command = [
            "rm", "-rf", "--", AiConfig.sandboxWorkspace
        ];
        resetSandboxWorkspace.running = true;
    }

    function continueBackendStartup() {
        if (codexUpdateRequested) {
            beginCodexUpdate();
        } else {
            syncChatKit();
        }
    }

    function syncChatKit() {
        if (resolvedSandboxName.length === 0 || chatKitSync.running) {
            return;
        }
        transport.stop();
        codexAuthorized = false;
        syncingChatKit = true;
        chatKitSync.running = true;
    }

    function showMaintenanceNotice(message) {
        maintenanceNotice = message;
        maintenanceNoticeTimer.restart();
    }

    function publishPendingMaintenanceNotice() {
        if (pendingMaintenanceNotice.length === 0) {
            return;
        }
        showMaintenanceNotice(pendingMaintenanceNotice);
        pendingMaintenanceNotice = "";
    }

    function maintenanceBlocked() {
        return attachmentsBusy || submissionStarting || isGenerating
            || sandboxSetupRunning || syncingChatKit || codexUpdating
            || rebuildingSandbox;
    }

    function requestCodexUpdate() {
        if (maintenanceBlocked()) {
            lastError = "Wait for the current chat operation to finish before updating Codex.";
            return;
        }
        codexUpdateRequested = true;
        pendingMaintenanceNotice = "Codex update complete";
        lastError = "";
        if (resolvedSandboxName.length === 0) {
            startBackend();
        } else {
            beginCodexUpdate();
        }
    }

    function beginCodexUpdate() {
        if (resolvedSandboxName.length === 0 || codexUpdate.running) {
            return;
        }
        transport.stop();
        codexAuthorized = false;
        codexUpdating = true;
        codexUpdate.running = true;
    }

    function clearConversationForRebuild() {
        conversationGeneration++;
        overloadRetry.stop();
        overloadRetry.pending = null;
        currentThreadId = "";
        currentTurnId = "";
        currentTitle = "New conversation";
        queuedSubmission = null;
        submissionStarting = false;
        isGenerating = false;
        captureRequested = false;
        pendingRequests = {};
        pendingThreadDeletes = [];
        deletingThreadId = "";
        clearConversationFiles();
        clearAttachments();
        messageModel.clear();
        screenshot.discard();
    }

    function beginSandboxRemoval() {
        if (removeChatSandbox.running) {
            return;
        }
        rebuildingSandbox = true;
        removeChatSandbox.running = true;
    }

    function requestSandboxRebuild() {
        if (maintenanceBlocked()) {
            lastError = "Wait for the current chat operation to finish before rebuilding.";
            return;
        }
        clearConversationForRebuild();
        transport.stop();
        codexAuthorized = false;
        codexUpdateRequested = true;
        rebuildRequested = true;
        pendingMaintenanceNotice = "Sandbox rebuilt and Codex updated";
        lastError = "";
        if (resolvedSandboxName.length > 0) {
            beginSandboxRemoval();
        } else {
            startBackend();
        }
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

    function pickFile() {
        if (attachmentsBusy) {
            return;
        }
        shown = false;
        screenshot.pickFile();
        if (resolvedSandboxName.length === 0) {
            startBackend();
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

        const previousThreadId = currentThreadId;
        if (isGenerating) {
            stop();
        }
        conversationGeneration++;
        if (overloadRetry.pending !== null
                && overloadRetry.pending.context.generation !== undefined) {
            overloadRetry.stop();
            overloadRetry.pending = null;
        }
        currentThreadId = "";
        currentTurnId = "";
        currentTitle = "New conversation";
        queuedSubmission = null;
        submissionStarting = false;
        isGenerating = false;
        captureRequested = false;
        if (transport.state === "streaming") {
            transport.state = "ready";
        }
        clearConversationFiles();
        messageModel.clear();
        clearAttachments();
        screenshot.discard();
        lastError = "";
        focusComposer();
        queueThreadDeletion(previousThreadId);
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
        if (maintenanceBlocked()) {
            lastError = "Wait for the current chat operation to finish before reconnecting.";
            return;
        }
        codexAuthorized = false;
        lastError = "";
        if (resolvedSandboxName.length === 0) {
            startBackend();
        } else {
            syncChatKit();
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
    function deleteNextQueuedThread() {
        if (!transport.ready || deletingThreadId.length > 0
                || pendingThreadDeletes.length === 0) {
            return;
        }

        const threadId = pendingThreadDeletes[0];
        const requestId = call("thread/delete", { threadId: threadId },
            "threadDelete", { threadId: threadId });
        if (requestId >= 0) {
            deletingThreadId = threadId;
        }
    }

    function finishThreadDeletion(threadId) {
        deletingThreadId = "";
        pendingThreadDeletes = pendingThreadDeletes.filter(
            candidate => candidate !== threadId);
        deleteNextQueuedThread();
    }

    function queueThreadDeletion(threadId) {
        const requestedThreadId = String(threadId || "");
        if (requestedThreadId.length === 0
                || pendingThreadDeletes.indexOf(requestedThreadId) >= 0) {
            return;
        }
        pendingThreadDeletes = pendingThreadDeletes.concat([requestedThreadId]);
        deleteNextQueuedThread();
    }

    function send(text) {
        const prompt = text.trim();
        if (submissionStarting || isGenerating || attachmentsBusy) {
            return;
        }
        if (prompt.length === 0 && attachmentModel.count === 0) {
            lastError = "Write a message or attach a file first.";
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
                lastError = "Wait for the attachment to finish copying, or remove it.";
                return;
            }
            attachments.push({
                token: attachment.token,
                hostPath: attachment.hostPath,
                sandboxPath: attachment.sandboxPath,
                kind: attachment.attachmentKind,
                displayName: attachment.displayName
            });
        }
        queuedSubmission = { text: prompt, attachments: attachments };
        submissionStarting = true;
        lastError = "";
        if (currentThreadId.length === 0) {
            const threadParams = {
                cwd: AiConfig.sandboxWorkingDirectory,
                approvalPolicy: "never",
                sandbox: "danger-full-access"
            };
            if (selectedModel.length > 0) {
                threadParams.model = selectedModel;
            }
            call("thread/start", threadParams, "threadStart",
                { generation: conversationGeneration });
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
            if (attachment.kind === "image") {
                input.push({ type: "localImage", path: attachment.sandboxPath });
            } else {
                input.push({
                    type: "text",
                    text: "A user-selected text file is available inside the sandbox at "
                        + attachment.sandboxPath + ". Read it when relevant to the request."
                });
            }
        }
        call("turn/start", modelSettings({
            threadId: currentThreadId,
            input: input,
            cwd: AiConfig.sandboxWorkingDirectory,
            approvalPolicy: "never",
            sandboxPolicy: { type: "dangerFullAccess" }
        }), "turnStart", {
            submission: queuedSubmission,
            generation: conversationGeneration
        });
    }

    function stop() {
        if (!isGenerating || currentThreadId.length === 0 || currentTurnId.length === 0) {
            return;
        }
        call("turn/interrupt", {
            threadId: currentThreadId,
            turnId: currentTurnId
        }, "interrupt", { generation: conversationGeneration });
    }

    function appendMessage(role, text, status, threadId, turnId, itemId, attachments) {
        const attachmentEntries = [];
        const items = attachments || [];
        for (const item of items) {
            attachmentEntries.push({
                hostPath: String(item.hostPath || ""),
                attachmentKind: String(item.kind || "image"),
                displayName: String(item.displayName || "Attachment")
            });
        }
        messageModel.append({
            messageId: Date.now().toString(36) + "-" + messageModel.count,
            role: role,
            body: text,
            messageStatus: status,
            threadId: threadId || "",
            turnId: turnId || "",
            itemId: itemId || "",
            attachments: attachmentEntries,
            activityType: "",
            activityTitle: "",
            activityOutput: "",
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
        const responseGeneration = pending.context.generation;
        if (responseGeneration !== undefined
                && responseGeneration !== conversationGeneration) {
            if (succeeded && pending.kind === "threadStart") {
                const staleThreadId = String(payload.thread
                    ? payload.thread.id : payload.threadId || "");
                queueThreadDeletion(staleThreadId);
            }
            return;
        }

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
            if (pending.kind === "threadDelete") {
                const reason = String(payload.message || "unknown app-server error");
                lastError = "New chat started, but Codex could not delete its "
                    + "previous thread: " + reason;
                finishThreadDeletion(pending.context.threadId);
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
            const requiresOpenaiAuth = payload && payload.requiresOpenaiAuth === true;
            if (requiresOpenaiAuth) {
                codexAuthorized = false;
                transport.state = "error";
                lastError = "Codex authentication is unavailable. Configure credentials for the sbx Codex agent.";
                pendingMaintenanceNotice = "";
            } else {
                codexAuthorized = true;
                transport.reconnectAttempt = 0;
                call("model/list", {
                    limit: 100,
                    includeHidden: false
                }, "modelList", {});
                if (currentThreadId.length > 0) {
                    call("thread/resume", { threadId: currentThreadId },
                        "threadResume", { generation: conversationGeneration });
                } else {
                    transport.state = "ready";
                    publishPendingMaintenanceNotice();
                    deleteNextQueuedThread();
                }
            }
        } else if (pending.kind === "modelList") {
            updateModels(payload);
        } else if (pending.kind === "threadResume") {
            const resumedThread = payload.thread || {};
            currentThreadId = String(resumedThread.id || currentThreadId);
            transport.state = "ready";
            publishPendingMaintenanceNotice();
            deleteNextQueuedThread();
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
                currentTurnId, "", submission.attachments);
            appendTurnPlaceholder();
            queuedSubmission = null;
            submissionStarting = false;
            isGenerating = true;
            transport.state = "streaming";
            attachmentModel.clear();
            submissionAccepted();
        } else if (pending.kind === "threadDelete") {
            finishThreadDeletion(pending.context.threadId);
        }
    }

    function handleNotification(method, params) {
        const notificationThreadId = String(params.threadId || "");
        if (notificationThreadId.length > 0
                && notificationThreadId !== currentThreadId) {
            return;
        }

        if (method === "turn/started") {
            const turn = params.turn || {};
            currentTurnId = String(turn.id || params.turnId || currentTurnId);
            return;
        }
        if (method === "item/started") {
            const item = params.item || {};
            if (AiChatLogic.isActivityItem(item)) {
                removeTurnPlaceholder();
                appendActivity(item, "streaming");
            }
            return;
        }
        if (method === "item/agentMessage/delta") {
            const itemId = String(params.itemId || "");
            let index = findAssistantMessage(itemId);
            if (index < 0) {
                removeTurnPlaceholder();
                index = appendMessage("assistant", "", "streaming", currentThreadId,
                    currentTurnId, itemId, []);
            }
            messageModel.setProperty(index, "body",
                messageModel.get(index).body + String(params.delta || ""));
            return;
        }
        if (method === "item/reasoning/summaryPartAdded") {
            const index = findActivity(String(params.itemId || ""));
            if (index >= 0 && messageModel.get(index).body.length > 0) {
                appendActivityText(params.itemId, "\n\n", false);
            }
            return;
        }
        if (method === "item/reasoning/summaryTextDelta"
                || method === "item/reasoning/textDelta"
                || method === "item/plan/delta") {
            appendActivityText(params.itemId, params.delta, false);
            return;
        }
        if (method === "item/commandExecution/outputDelta") {
            appendActivityText(params.itemId, params.delta, true);
            return;
        }
        if (method === "item/completed") {
            const item = params.item || {};
            if (item.type === "agentMessage") {
                const itemId = String(item.id || params.itemId || "");
                let index = findAssistantMessage(itemId);
                if (index < 0) {
                    removeTurnPlaceholder();
                    index = appendMessage("assistant", "", "completed",
                        currentThreadId, currentTurnId, itemId, []);
                }
                if (item.text !== undefined) {
                    messageModel.setProperty(index, "body", String(item.text));
                }
                messageModel.setProperty(index, "messageStatus", "completed");
                messageModel.setProperty(index, "itemId", itemId);
            } else if (AiChatLogic.isActivityItem(item)) {
                removeTurnPlaceholder();
                appendActivity(item, "completed");
            }
            return;
        }
        if (method === "error") {
            const eventError = params.error || {};
            const message = String(eventError.message || params.message
                || "The Codex turn failed.").slice(0, 600);
            lastError = message;
            for (let index = messageModel.count - 1; index >= 0; index--) {
                const entry = messageModel.get(index);
                if (entry.role === "assistant"
                        && entry.messageStatus === "streaming") {
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
            transport.state = "ready";
            for (const attachment of currentTurnAttachments) {
                screenshot.removeSandboxFile(attachment.sandboxPath);
            }
            currentTurnAttachments = [];
            for (let index = messageModel.count - 1; index >= 0; index--) {
                const entry = messageModel.get(index);
                if (entry.turnId !== currentTurnId
                        || entry.messageStatus !== "streaming") {
                    continue;
                }
                messageModel.setProperty(index, "messageStatus",
                    status === "completed" ? "completed" : status);
                if (entry.role === "assistant" && failureMessage.length > 0) {
                    messageModel.setProperty(index, "errorText", failureMessage);
                }
            }
            currentTurnId = "";
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

    TextEdit {
        id: clipboardBuffer
        visible: false
    }

    Timer {
        id: maintenanceNoticeTimer
        interval: 4000
        onTriggered: root.maintenanceNotice = ""
    }

    Process {
        id: chatKitSync

        command: [
            "bash", Quickshell.shellPath("AiChatKitSync.sh"),
            root.resolvedSandboxName
        ]
        stderr: StdioCollector { id: chatKitSyncError }
        onExited: function(exitCode) {
            root.syncingChatKit = false;
            if (exitCode !== 0) {
                const diagnostic = chatKitSyncError.text.trim().slice(0, 600);
                root.pendingMaintenanceNotice = "";
                transport.state = "error";
                root.lastError = diagnostic.length > 0
                    ? "Could not load the AI chat kit: " + diagnostic
                    : "Could not load the AI chat kit into the sandbox.";
                return;
            }
            transport.start();
        }
    }

    Process {
        id: codexUpdate

        command: AiConfig.sbxCommand.concat([
            "exec", root.resolvedSandboxName, "sh", "-lc", "exec codex update"
        ])
        stdout: StdioCollector { id: codexUpdateOutput }
        stderr: StdioCollector { id: codexUpdateError }
        onExited: function(exitCode) {
            root.codexUpdating = false;
            root.codexUpdateRequested = false;
            if (exitCode !== 0) {
                const diagnostic = (codexUpdateError.text.trim()
                    || codexUpdateOutput.text.trim()).slice(0, 600);
                root.pendingMaintenanceNotice = "";
                root.lastError = diagnostic.length > 0
                    ? "Codex update failed: " + diagnostic
                    : "Codex update failed.";
            }
            root.syncChatKit();
        }
    }

    Process {
        id: removeChatSandbox

        command: AiConfig.sbxCommand.concat([
            "rm", "--force", AiConfig.sandboxName
        ])
        stderr: StdioCollector { id: removeChatSandboxError }
        onExited: function(exitCode) {
            root.rebuildingSandbox = false;
            root.rebuildRequested = false;
            if (exitCode !== 0) {
                const diagnostic = removeChatSandboxError.text.trim().slice(0, 600);
                root.codexUpdateRequested = false;
                root.pendingMaintenanceNotice = "";
                transport.state = "error";
                root.lastError = diagnostic.length > 0
                    ? "Could not rebuild the Codex sandbox: " + diagnostic
                    : "Could not remove the Codex sandbox for rebuilding.";
                return;
            }
            root.resolvedSandboxName = "";
            root.startBackend();
        }
    }

    Timer {
        id: sandboxSetupTimeout

        repeat: false
        onTriggered: {
            if (root.sandboxSetupStage.length === 0) {
                return;
            }
            const stage = root.sandboxSetupStage;
            root.sandboxSetupTimedOut = true;
            root.stopSandboxSetupProcess();
            root.failSandboxSetup(root.sandboxSetupTimeoutMessage(stage));
        }
    }

    Process {
        id: sandboxDiscovery

        command: AiConfig.sbxCommand.concat(["ls", "-q"])
        stdout: StdioCollector { id: sandboxListOutput }
        stderr: StdioCollector { id: sandboxListError }
        onExited: function(exitCode) {
            sandboxSetupTimeout.stop();
            if (root.sandboxSetupTimedOut) {
                return;
            }
            if (exitCode !== 0) {
                const diagnostic = sandboxListError.text.trim().slice(0, 180);
                root.failSandboxSetup(diagnostic.length > 0
                    ? "Could not list sbx sandboxes: " + diagnostic
                    : "Could not list sbx sandboxes. Run sbx ls in a terminal.");
                return;
            }
            const sandboxes = sandboxListOutput.text.split(/\r?\n/)
                .map(name => name.trim()).filter(name => name.length > 0);
            if (sandboxes.indexOf(AiConfig.sandboxName) < 0) {
                root.rebuildRequested = false;
                root.createSandbox();
                return;
            }

            root.resolvedSandboxName = AiConfig.sandboxName;
            root.finishSandboxSetup();
            if (root.rebuildRequested) {
                root.beginSandboxRemoval();
                return;
            }
            if (root.captureRequested) {
                root.beginCapture();
            }
            root.continueBackendStartup();
        }
    }

    Process {
        id: resetSandboxWorkspace

        stderr: StdioCollector { id: resetWorkspaceError }
        onExited: function(exitCode) {
            sandboxSetupTimeout.stop();
            if (root.sandboxSetupTimedOut) {
                return;
            }
            if (exitCode !== 0) {
                root.failSandboxSetup(
                    "Could not reset the private AI sandbox workspace: "
                        + resetWorkspaceError.text.trim().slice(0, 180));
                return;
            }
            prepareSandboxWorkspace.command = [
                "install", "-d", "-m", "700", "--", AiConfig.sandboxWorkspace
            ];
            root.beginSandboxSetupStage(
                "preparing", AiConfig.sandboxWorkspaceTimeoutMs);
            prepareSandboxWorkspace.running = true;
        }
    }

    Process {
        id: prepareSandboxWorkspace

        onExited: function(exitCode) {
            sandboxSetupTimeout.stop();
            if (root.sandboxSetupTimedOut) {
                return;
            }
            if (exitCode !== 0) {
                root.failSandboxSetup(
                    "Could not create the private AI sandbox workspace.");
                return;
            }
            createChatSandbox.command = AiConfig.sbxCommand.concat([
                "create", "codex", AiConfig.sandboxWorkspace,
                "--name", AiConfig.sandboxName, "--quiet"
            ]);
            root.beginSandboxSetupStage(
                "creating", AiConfig.sandboxCreateTimeoutMs);
            createChatSandbox.running = true;
        }
    }

    Process {
        id: createChatSandbox

        stdout: StdioCollector {}
        stderr: StdioCollector { id: createSandboxError }
        onExited: function(exitCode) {
            sandboxSetupTimeout.stop();
            if (root.sandboxSetupTimedOut) {
                return;
            }
            if (exitCode !== 0) {
                const diagnostic = createSandboxError.text.trim().slice(0, 600);
                root.failSandboxSetup(
                    "sbx create failed for " + AiConfig.sandboxName
                        + " using " + AiConfig.sandboxWorkspace + ": " + diagnostic);
                console.warn("AI sandbox creation failed:", diagnostic);
                return;
            }
            root.resolvedSandboxName = AiConfig.sandboxName;
            root.diagnosticText = "Using dedicated sandbox " + root.resolvedSandboxName;
            root.finishSandboxSetup();
            if (root.captureRequested) {
                root.beginCapture();
            }
            root.continueBackendStartup();
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
                root.deletingThreadId = "";
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
                root.deletingThreadId = "";
                root.codexAuthorized = false;
                overloadRetry.stop();
                overloadRetry.pending = null;
                if (root.submissionStarting) {
                    root.submissionStarting = false;
                    root.queuedSubmission = null;
                }
                if (root.isGenerating) {
                    root.isGenerating = false;
                    for (const attachment of root.currentTurnAttachments) {
                        screenshot.removeSandboxFile(attachment.sandboxPath);
                    }
                    root.currentTurnAttachments = [];
                    for (let index = root.messages.count - 1; index >= 0; index--) {
                        const message = root.messages.get(index);
                        if (message.turnId === root.currentTurnId
                                && message.messageStatus === "streaming") {
                            root.messages.setProperty(index, "messageStatus", "failed");
                        }
                    }
                    root.currentTurnId = "";
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

        onCaptured: (token, hostPath, sandboxPath, attachmentKind, displayName) => {
            attachmentModel.append({
                token: token,
                hostPath: hostPath,
                sandboxPath: sandboxPath,
                attachmentKind: attachmentKind,
                displayName: displayName,
                status: "copying",
                errorText: ""
            });
            root.shown = true;
            Qt.callLater(() => root.focusComposer());
        }
        onReady: (token, hostPath, sandboxPath, attachmentKind, displayName) => {
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
            if (pending === null) {
                return;
            }
            if (!transport.ready) {
                if (pending.kind === "threadDelete") {
                    root.deletingThreadId = "";
                } else {
                    root.lastError = "Codex is busy; retry when the backend is ready.";
                    root.submissionStarting = false;
                }
                pending = null;
                return;
            }
            const requestId = transport.request(pending.method, pending.params);
            if (requestId < 0) {
                if (pending.kind === "threadDelete") {
                    root.deletingThreadId = "";
                } else {
                    root.submissionStarting = false;
                }
                pending = null;
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
        function attachImportedFile(path: string, kind: string, displayName: string): void {
            screenshot.acceptImportedFile(path, kind, displayName);
        }
        function attachmentCancelled(): void {
            screenshot.cancelImport();
        }
        function attachmentFailed(message: string): void {
            screenshot.failImport(message);
        }
    }

    AiChatView {
        controller: root
    }

}
