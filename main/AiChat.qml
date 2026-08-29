import QtQuick
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

    function commandDraft(draft) {
        const text = String(draft || "");
        for (let index = text.length - 1; index >= 0; index--) {
            if (text.charAt(index) !== "/") {
                continue;
            }
            if (index === 0 || /\s/.test(text.charAt(index - 1))) {
                return text.slice(index);
            }
        }
        return "";
    }

    function replaceCommandDraft(draft, replacement) {
        const text = String(draft || "");
        const command = commandDraft(text);
        if (command.length === 0) {
            return text;
        }
        return text.slice(0, text.length - command.length)
            + String(replacement || "");
    }

    function removeCommandDraft(draft) {
        return replaceCommandDraft(draft, "").replace(/\s+$/, "");
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
            { label: "/file", detail: "Attach an image or text file", draft: "/file", immediate: true },
            { label: "/ps", detail: "Capture a screen region", draft: "/ps", immediate: true },
            { label: "/copy", detail: "Copy the entire chat", draft: "/copy", immediate: true },
            { label: "/model", detail: "Change model", draft: "/model ", immediate: false },
            { label: "/thinking", detail: "Change thinking level", draft: "/thinking ", immediate: false },
            { label: "/new", detail: "Start a new chat", draft: "/new", immediate: true },
            { label: "/reconnect", detail: "Reload the chat kit and backend", draft: "/reconnect", immediate: true },
            { label: "/update", detail: "Update Codex and reconnect", draft: "/update", immediate: true },
            { label: "/rebuild", detail: "Recreate the sandbox and update Codex", draft: "/rebuild", immediate: true }
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
        if (command === "/file") {
            pickFile();
        } else if (command === "/ps" || command === "/screenshot") {
            captureRegion();
        } else if (command === "/copy") {
            copyChat();
        } else if (command === "/model") {
            chooseModel(argument);
        } else if (command === "/thinking" || command === "/effort") {
            chooseEffort(argument);
        } else if (command === "/new") {
            newChat();
        } else if (command === "/reconnect") {
            reconnect();
        } else if (command === "/update") {
            requestCodexUpdate();
        } else if (command === "/rebuild") {
            requestSandboxRebuild();
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

    function markdownBlocks(value) {
        const lines = String(value || "").split("\n");
        const blocks = [];
        let kind = "markdown";
        let language = "";
        let buffer = [];

        function flushBlock() {
            const text = buffer.join("\n");
            if (kind === "code" || text.length > 0) {
                blocks.push({
                    kind: kind,
                    language: language,
                    text: text
                });
            }
            buffer = [];
        }

        for (const line of lines) {
            if (kind === "markdown") {
                const openingFence = line.match(/^[ \t]*```([^`]*)$/);
                if (openingFence !== null) {
                    flushBlock();
                    kind = "code";
                    language = openingFence[1].trim();
                } else {
                    buffer.push(line);
                }
            } else if (/^[ \t]*```[ \t]*$/.test(line)) {
                flushBlock();
                kind = "markdown";
                language = "";
            } else {
                buffer.push(line);
            }
        }
        flushBlock();

        if (blocks.length === 0) {
            blocks.push({ kind: "markdown", language: "", text: "" });
        }
        return blocks;
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

    function textFromBlocks(value) {
        if (!Array.isArray(value)) {
            return typeof value === "string" ? value : "";
        }
        const parts = [];
        for (const entry of value) {
            if (typeof entry === "string") {
                parts.push(entry);
            } else if (entry && entry.text !== undefined) {
                parts.push(String(entry.text));
            }
        }
        return parts.join("\n\n");
    }

    function prettyValue(value) {
        if (value === undefined || value === null || value === "") {
            return "";
        }
        if (typeof value === "string") {
            return value;
        }
        try {
            return JSON.stringify(value, null, 2);
        } catch (error) {
            return String(value);
        }
    }

    function normalizedActivityStatus(value, fallback) {
        const status = String(value || fallback || "streaming");
        return status === "inProgress" ? "streaming" : status;
    }

    function activityStatusLabel(value) {
        const status = normalizedActivityStatus(value, "");
        if (status === "streaming") {
            return "Running";
        }
        if (status === "completed") {
            return "Done";
        }
        if (status === "failed") {
            return "Failed";
        }
        if (status === "declined") {
            return "Declined";
        }
        if (status === "interrupted") {
            return "Stopped";
        }
        return titleCase(status);
    }

    function activityTitle(item) {
        const type = String(item && item.type || "activity");
        if (type === "turn" || type === "reasoning") {
            return "Thinking";
        }
        if (type === "plan") {
            return "Planning";
        }
        if (type === "commandExecution") {
            return "Shell command";
        }
        if (type === "fileChange") {
            return "Editing files";
        }
        if (type === "mcpToolCall") {
            const context = item.appContext || {};
            const owner = String(context.appName || item.server || "Tool");
            const action = String(context.actionName || item.tool || "");
            return action.length > 0 ? owner + ": " + action : owner;
        }
        if (type === "collabToolCall") {
            return "Agent: " + String(item.tool || "collaboration");
        }
        if (type === "webSearch") {
            return "Web search";
        }
        if (type === "imageGeneration") {
            return "Generating image";
        }
        if (type === "imageView") {
            return "Viewing image";
        }
        if (type === "sleep") {
            return "Waiting";
        }
        if (type === "contextCompaction") {
            return "Compacting conversation";
        }
        if (type === "enteredReviewMode") {
            return "Reviewing";
        }
        if (type === "exitedReviewMode") {
            return "Review complete";
        }
        if (type === "dynamicToolCall") {
            return "Tool: " + String(item.tool || "call");
        }
        return titleCase(type.replace(/([a-z0-9])([A-Z])/g, "$1 $2"));
    }

    function activityBody(item) {
        const type = String(item && item.type || "");
        if (type === "reasoning") {
            return textFromBlocks(item.summary) || textFromBlocks(item.content);
        }
        if (type === "plan") {
            return String(item.text || "");
        }
        if (type === "commandExecution") {
            const command = String(item.command || "");
            return command.length > 0 ? "$ " + command : "";
        }
        if (type === "fileChange") {
            const changes = Array.isArray(item.changes) ? item.changes : [];
            return changes.map(change => {
                const kind = String(change.kind || "change");
                return titleCase(kind) + ": " + String(change.path || "");
            }).join("\n");
        }
        if (type === "mcpToolCall" || type === "dynamicToolCall") {
            return prettyValue(item.arguments);
        }
        if (type === "collabToolCall") {
            return String(item.prompt || item.agentStatus || "");
        }
        if (type === "webSearch") {
            return String(item.query || prettyValue(item.action));
        }
        if (type === "imageView") {
            return String(item.path || "");
        }
        if (type === "imageGeneration") {
            return String(item.revisedPrompt || "");
        }
        if (type === "sleep") {
            const duration = Number(item.durationMs || 0);
            return duration > 0 ? "Waiting " + (duration / 1000).toFixed(1) + " seconds" : "";
        }
        if (type === "enteredReviewMode" || type === "exitedReviewMode") {
            return String(item.review || "");
        }
        return "";
    }

    function activityOutput(item) {
        if (String(item && item.type || "") === "commandExecution") {
            return String(item.aggregatedOutput || "");
        }
        if (String(item && item.type || "") === "mcpToolCall") {
            return prettyValue(item.error || item.result);
        }
        return "";
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
        const status = normalizedActivityStatus(item.status, fallbackStatus);
        if (index < 0) {
            index = appendMessage("activity", activityBody(item), status,
                currentThreadId, currentTurnId, itemId, []);
        } else {
            const body = activityBody(item);
            if (body.length > 0 || messageModel.get(index).body.length === 0) {
                messageModel.setProperty(index, "body", body);
            }
            messageModel.setProperty(index, "messageStatus", status);
        }
        messageModel.setProperty(index, "activityType", String(item.type || "activity"));
        messageModel.setProperty(index, "activityTitle", activityTitle(item));
        const output = activityOutput(item);
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

    function isActivityItem(item) {
        const type = String(item && item.type || "");
        return type.length > 0 && type !== "agentMessage"
            && type !== "userMessage" && type !== "functionCallOutput";
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
            if (isActivityItem(item)) {
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
            } else if (isActivityItem(item)) {
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

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: chatWindow

            required property var modelData
            readonly property var monitor: Hyprland.monitorFor(modelData)
            readonly property bool focusedScreen: monitor !== null && monitor.focused

            function acceptMenuItem(item) {
                if (item.immediate) {
                    composer.text = root.removeCommandDraft(composer.text);
                    composer.cursorPosition = composer.length;
                    root.executeSlashCommand(item.draft);
                    return;
                }

                composer.text = root.replaceCommandDraft(composer.text, item.draft);
                composer.cursorPosition = composer.length;
                composer.forceActiveFocus();
            }

            function submitComposer() {
                if (root.isGenerating) {
                    root.stop();
                    return;
                }

                const draft = composer.text.trim();
                const activeCommand = root.commandDraft(composer.text);
                if (activeCommand.length > 0) {
                    const items = root.commandItems(activeCommand);
                    for (const item of items) {
                        if (item.immediate
                                && item.draft.trim() === activeCommand.trim()) {
                            acceptMenuItem(item);
                            return;
                        }
                    }
                    if (commandPalette.visible && items.length > 0) {
                        acceptMenuItem(items[Math.max(0, commandList.currentIndex)]);
                        return;
                    }
                    if (draft === activeCommand.trim()) {
                        if (root.executeSlashCommand(activeCommand)) {
                            composer.clear();
                        }
                        return;
                    }
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
                    ? Math.min(AiConfig.chatMaxHeight, parent.height * 0.86)
                    : Math.min(Math.max(164, composerStack.implicitHeight + 4),
                        parent.height - 32)
                radius: root.conversationStarted ? 24 : 30
                color: "#171717"
                border.width: 1
                border.color: "#3d3d3d"
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
                        Layout.preferredHeight: visible ? 56 : 0
                        visible: root.conversationStarted

                        Rectangle {
                            width: 34
                            height: 34
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 20 }
                            radius: 17
                            color: closeMouse.containsMouse ? "#292929" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: "#969696"
                                font.family: Theme.fontFamily
                                font.pixelSize: 23
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
                            width: parent.width - 144
                            text: root.currentTitle
                            color: "#f2f2f2"
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                    }

                    ListView {
                        id: messageList
                        Layout.fillWidth: true
                        Layout.fillHeight: visible
                        Layout.preferredHeight: visible ? -1 : 0
                        Layout.leftMargin: 28
                        Layout.rightMargin: 28
                        Layout.topMargin: 12
                        Layout.bottomMargin: 24
                        visible: root.conversationStarted
                        model: root.messages
                        spacing: 24
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
                            required property string itemId
                            required property string activityType
                            required property string activityTitle
                            required property string activityOutput
                            required property var attachments
                            property bool activityExpanded: false
                            property bool answerCopied: false
                            readonly property int attachmentCount: attachments
                                && attachments.count !== undefined
                                    ? attachments.count
                                    : attachments && attachments.length
                                        ? attachments.length : 0
                            width: ListView.view.width
                            implicitHeight: messageBubble.implicitHeight

                            TextMetrics {
                                id: messageMetrics
                                text: body
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                            }

                            Timer {
                                id: answerCopyReset
                                interval: 1400
                                onTriggered: answerCopied = false
                            }

                            Rectangle {
                                id: messageBubble
                                width: role === "user"
                                    ? Math.min(parent.width * 0.78,
                                        Math.max(attachmentCount > 0 ? 320 : 88,
                                            messageMetrics.advanceWidth + 40))
                                    : parent.width
                                implicitHeight: messageContent.implicitHeight
                                    + (role === "user" ? 28 : 0)
                                anchors.right: role === "user" ? parent.right : undefined
                                radius: role === "user" ? 18 : 0
                                color: role === "user" ? "#2a2a2a" : "transparent"

                                ColumnLayout {
                                    id: messageContent
                                    anchors {
                                        fill: parent
                                        margins: role === "user" ? 14 : 0
                                    }
                                    spacing: 10

                                    Repeater {
                                        model: attachments
                                        Rectangle {
                                            required property string hostPath
                                            required property string attachmentKind
                                            required property string displayName
                                            Layout.preferredWidth: Math.min(300,
                                                messageBubble.width - 24)
                                            Layout.preferredHeight: attachmentKind === "image"
                                                ? 150 : 48
                                            radius: 12
                                            color: "#202020"
                                            clip: true

                                            Image {
                                                anchors.fill: parent
                                                visible: attachmentKind === "image"
                                                source: visible ? "file://" + hostPath : ""
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                            }

                                            RowLayout {
                                                anchors { fill: parent; margins: 10 }
                                                visible: attachmentKind === "text"
                                                spacing: 10

                                                Rectangle {
                                                    Layout.preferredWidth: 28
                                                    Layout.preferredHeight: 28
                                                    radius: 7
                                                    color: "#343434"

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "TXT"
                                                        color: "#cfcfcf"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 8
                                                        font.weight: Font.DemiBold
                                                    }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: displayName
                                                    color: "#dedede"
                                                    elide: Text.ElideMiddle
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                }
                                            }
                                        }
                                    }

                                    TextEdit {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: visible ? contentHeight : 0
                                        visible: role !== "assistant" && role !== "activity"
                                            && body.length > 0
                                        text: body
                                        textFormat: Text.PlainText
                                        wrapMode: Text.Wrap
                                        color: role === "notice" ? "#b4b4b4" : "#eeeeee"
                                        selectionColor: "#515151"
                                        selectedTextColor: "#ffffff"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 15
                                        readOnly: true
                                        selectByMouse: true
                                    }

                                    Rectangle {
                                        id: activityCard
                                        readonly property string detailText: body
                                            + (activityOutput.length > 0
                                                ? (body.length > 0 ? "\n\n" : "") + activityOutput
                                                : "")

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: visible
                                            ? activityLayout.implicitHeight + 24 : 0
                                        visible: role === "activity"
                                        radius: 12
                                        color: "#202020"
                                        border.width: 1
                                        border.color: "#343434"

                                        ColumnLayout {
                                            id: activityLayout
                                            anchors {
                                                left: parent.left
                                                right: parent.right
                                                top: parent.top
                                                margins: 12
                                            }
                                            spacing: 8

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 10

                                                Rectangle {
                                                    Layout.preferredWidth: 9
                                                    Layout.preferredHeight: 9
                                                    radius: 5
                                                    color: messageStatus === "failed"
                                                        || messageStatus === "declined"
                                                            ? Theme.red
                                                            : messageStatus === "completed"
                                                                ? Theme.green : Theme.blue

                                                    SequentialAnimation on opacity {
                                                        running: activityCard.visible
                                                            && messageStatus === "streaming"
                                                        loops: Animation.Infinite
                                                        NumberAnimation {
                                                            to: 0.3
                                                            duration: 520
                                                            easing.type: Easing.InOutSine
                                                        }
                                                        NumberAnimation {
                                                            to: 1
                                                            duration: 520
                                                            easing.type: Easing.InOutSine
                                                        }
                                                    }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: activityTitle
                                                    color: "#e8e8e8"
                                                    elide: Text.ElideRight
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.DemiBold
                                                }

                                                Text {
                                                    text: root.activityStatusLabel(messageStatus)
                                                    color: messageStatus === "failed"
                                                        || messageStatus === "declined"
                                                            ? Theme.red : "#858585"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                visible: activityCard.detailText.length > 0
                                                text: activityCard.detailText
                                                color: "#aaaaaa"
                                                wrapMode: Text.WrapAnywhere
                                                maximumLineCount: activityExpanded ? 1000 : 5
                                                elide: Text.ElideRight
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                lineHeight: 1.15
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: activityCard.detailText.length > 0
                                            cursorShape: enabled
                                                ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: activityExpanded = !activityExpanded
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: visible ? implicitHeight : 0
                                        visible: role === "assistant" && body.length > 0
                                        spacing: 10

                                        Repeater {
                                            model: root.markdownBlocks(body)

                                            ColumnLayout {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                spacing: 0

                                                TextEdit {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: visible
                                                        ? contentHeight : 0
                                                    visible: modelData.kind === "markdown"
                                                        && modelData.text.length > 0
                                                    text: root.safeAssistantMarkdown(modelData.text)
                                                    textFormat: Text.MarkdownText
                                                    wrapMode: Text.Wrap
                                                    color: "#eeeeee"
                                                    selectionColor: "#515151"
                                                    selectedTextColor: "#ffffff"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 15
                                                    readOnly: true
                                                    selectByMouse: true
                                                    onLinkActivated: link => root.openLink(link)
                                                }

                                                Rectangle {
                                                    id: codeBlock
                                                    property bool copied: false

                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: visible
                                                        ? codeLayout.implicitHeight + 20 : 0
                                                    visible: modelData.kind === "code"
                                                    radius: 10
                                                    color: "#111111"
                                                    border.width: 1
                                                    border.color: "#343434"

                                                    Timer {
                                                        id: codeCopyReset
                                                        interval: 1400
                                                        onTriggered: codeBlock.copied = false
                                                    }

                                                    ColumnLayout {
                                                        id: codeLayout
                                                        anchors {
                                                            left: parent.left
                                                            right: parent.right
                                                            top: parent.top
                                                            margins: 10
                                                        }
                                                        spacing: 8

                                                        RowLayout {
                                                            Layout.fillWidth: true

                                                            Text {
                                                                Layout.fillWidth: true
                                                                text: modelData.language.length > 0
                                                                    ? modelData.language : "code"
                                                                color: "#858585"
                                                                font.family: Theme.fontFamily
                                                                font.pixelSize: 11
                                                            }

                                                            Rectangle {
                                                                Layout.preferredWidth: 30
                                                                Layout.preferredHeight: 26
                                                                radius: 7
                                                                color: codeCopyMouse.containsMouse
                                                                    ? "#343434" : "#242424"

                                                                Item {
                                                                    anchors.centerIn: parent
                                                                    width: 15
                                                                    height: 15

                                                                    Rectangle {
                                                                        x: 4
                                                                        width: 10
                                                                        height: 10
                                                                        radius: 1
                                                                        color: "transparent"
                                                                        border.width: 1
                                                                        border.color: codeBlock.copied
                                                                            ? Theme.green : "#b5b5b5"
                                                                    }

                                                                    Rectangle {
                                                                        y: 4
                                                                        width: 10
                                                                        height: 10
                                                                        radius: 1
                                                                        color: codeCopyMouse.containsMouse
                                                                            ? "#343434" : "#242424"
                                                                        border.width: 1
                                                                        border.color: codeBlock.copied
                                                                            ? Theme.green : "#b5b5b5"
                                                                    }
                                                                }

                                                                MouseArea {
                                                                    id: codeCopyMouse
                                                                    anchors.fill: parent
                                                                    hoverEnabled: true
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onClicked: {
                                                                        if (root.copyText(modelData.text)) {
                                                                            codeBlock.copied = true;
                                                                            codeCopyReset.restart();
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        TextEdit {
                                                            Layout.fillWidth: true
                                                            Layout.preferredHeight: contentHeight
                                                            text: modelData.text
                                                            textFormat: Text.PlainText
                                                            wrapMode: TextEdit.WrapAnywhere
                                                            color: "#d8d8d8"
                                                            selectionColor: "#515151"
                                                            selectedTextColor: "#ffffff"
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 13
                                                            readOnly: true
                                                            selectByMouse: true
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 28

                                            Item { Layout.fillWidth: true }

                                            Rectangle {
                                                Layout.preferredWidth: 32
                                                Layout.preferredHeight: 28
                                                radius: 8
                                                color: answerCopyMouse.containsMouse
                                                    ? "#2d2d2d" : "transparent"

                                                Item {
                                                    anchors.centerIn: parent
                                                    width: 15
                                                    height: 15

                                                    Rectangle {
                                                        x: 4
                                                        width: 10
                                                        height: 10
                                                        radius: 1
                                                        color: "transparent"
                                                        border.width: 1
                                                        border.color: answerCopied
                                                            ? Theme.green : "#9b9b9b"
                                                    }

                                                    Rectangle {
                                                        y: 4
                                                        width: 10
                                                        height: 10
                                                        radius: 1
                                                        color: answerCopyMouse.containsMouse
                                                            ? "#2d2d2d" : "#171717"
                                                        border.width: 1
                                                        border.color: answerCopied
                                                            ? Theme.green : "#9b9b9b"
                                                    }
                                                }

                                                MouseArea {
                                                    id: answerCopyMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (root.copyText(body)) {
                                                            answerCopied = true;
                                                            answerCopyReset.restart();
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.preferredHeight: visible ? implicitHeight : 0
                                        visible: role !== "activity"
                                            && (messageStatus !== "completed"
                                                || errorText.length > 0)
                                        text: errorText.length > 0 ? errorText
                                            : messageStatus === "streaming"
                                                ? "Responding…" : messageStatus
                                        color: messageStatus === "failed"
                                            || errorText.length > 0
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
                            + (root.conversationStarted ? 20 : 4)

                        ColumnLayout {
                            id: composerStack
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                                leftMargin: root.conversationStarted ? 20 : 0
                                rightMargin: root.conversationStarted ? 20 : 0
                                bottomMargin: root.conversationStarted ? 20 : 4
                            }
                            spacing: 10

                            Rectangle {
                                id: commandPalette
                                readonly property string draft: root.commandDraft(composer.text)

                                Layout.fillWidth: true
                                Layout.preferredHeight: visible
                                    ? Math.min(288, commandList.contentHeight + 12) : 0
                                visible: draft.length > 0
                                    && root.commandItems(draft).length > 0
                                radius: 29
                                color: "#242424"
                                border.width: 1
                                border.color: "#3c3c3c"
                                clip: true

                                ListView {
                                    id: commandList
                                    anchors { fill: parent; margins: 6 }
                                    model: root.commandItems(commandPalette.draft)
                                    currentIndex: 0
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index
                                        width: ListView.view.width
                                        height: 46
                                        radius: height / 2
                                        color: index === commandList.currentIndex
                                            || commandMouse.containsMouse ? "#353535" : "transparent"

                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                                            spacing: 14

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
                                                color: "#8a8a8a"
                                                elide: Text.ElideRight
                                                horizontalAlignment: Text.AlignRight
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
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
                                Layout.preferredHeight: composerInner.implicitHeight + 24
                                radius: root.conversationStarted ? 22 : 28
                                color: root.conversationStarted ? "#272727" : "transparent"
                                border.width: root.conversationStarted ? 1 : 0
                                border.color: "#343434"

                                ColumnLayout {
                                    id: composerInner
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: parent.top
                                        leftMargin: root.conversationStarted ? 12 : 20
                                        rightMargin: root.conversationStarted ? 12 : 20
                                        topMargin: 12
                                    }
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        visible: root.pendingAttachments.count > 0
                                        spacing: 8

                                        Repeater {
                                            model: root.pendingAttachments
                                            Rectangle {
                                                required property string hostPath
                                                required property string attachmentKind
                                                required property string displayName
                                                required property int index
                                                Layout.preferredWidth: attachmentKind === "image"
                                                    ? 108 : 220
                                                Layout.preferredHeight: attachmentKind === "image"
                                                    ? 68 : 48
                                                radius: 10
                                                color: "#1c1c1c"
                                                clip: true

                                                Image {
                                                    anchors { fill: parent; margins: 3 }
                                                    visible: attachmentKind === "image"
                                                    source: visible ? "file://" + hostPath : ""
                                                    fillMode: Image.PreserveAspectFit
                                                }

                                                RowLayout {
                                                    anchors {
                                                        fill: parent
                                                        leftMargin: 10
                                                        rightMargin: 38
                                                        topMargin: 8
                                                        bottomMargin: 8
                                                    }
                                                    visible: attachmentKind === "text"
                                                    spacing: 9

                                                    Rectangle {
                                                        Layout.preferredWidth: 28
                                                        Layout.preferredHeight: 28
                                                        radius: 7
                                                        color: "#343434"

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "TXT"
                                                            color: "#cfcfcf"
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 8
                                                            font.weight: Font.DemiBold
                                                        }
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: displayName
                                                        color: "#dedede"
                                                        elide: Text.ElideMiddle
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 11
                                                    }
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
                                            root.conversationStarted ? 72 : 88,
                                            Math.min(144, composer.contentHeight + 32))

                                        Flickable {
                                            anchors {
                                                fill: parent
                                                leftMargin: 2
                                                rightMargin: 2
                                                topMargin: 4
                                                bottomMargin: 4
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
                                                        ? "Message Codex" : "Ask Codex anything locally"
                                                    color: "#707070"
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
                                        Layout.preferredHeight: 40
                                        Layout.leftMargin: 2
                                        Layout.rightMargin: 0
                                        spacing: 12

                                        RowLayout {
                                            visible: root.lastError.length === 0
                                                && !root.attachmentsBusy
                                            spacing: 7

                                            Rectangle {
                                                width: 7
                                                height: 7
                                                radius: 3.5
                                                color: root.maintenanceStatusVisible
                                                    ? Theme.blue
                                                    : root.codexAuthorized
                                                        ? Theme.green : "#666666"
                                            }

                                            Text {
                                                text: root.maintenanceStatusVisible
                                                    ? root.statusText
                                                    : root.codexAuthorized
                                                        ? "Authorized via sbx" : root.statusText
                                                color: root.maintenanceStatusVisible
                                                    ? Theme.blue
                                                    : root.codexAuthorized
                                                        ? "#a8b8a4" : "#858585"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: visible
                                            visible: root.lastError.length > 0
                                                || root.attachmentsBusy
                                            text: root.attachmentsBusy
                                                ? "Adding file…"
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
                                            font.pixelSize: 11
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: root.modelStatusText()
                                            color: "#d8d8d8"
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


    component ActionButton: Rectangle {
        id: actionButton
        property bool stopMode: false
        signal clicked()

        implicitWidth: 36
        implicitHeight: 36
        radius: 18
        color: stopMode ? "#f4f4f4"
            : actionMouse.containsMouse && enabled ? "#dedede" : "#a8a8a8"
        opacity: enabled ? 1 : 0.38

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
                context.moveTo(11, 18);
                context.lineTo(18, 11);
                context.lineTo(25, 18);
                context.moveTo(18, 11);
                context.lineTo(18, 25);
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
