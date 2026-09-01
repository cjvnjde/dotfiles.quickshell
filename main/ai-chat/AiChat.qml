import QtQuick
import Quickshell
import Quickshell.Io
import "AiChatLogic.js" as AiChatLogic
import ".."

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
    property string selectedModel: chatPreferences.selectedModel
    property string selectedModelName: "Codex"
    property string selectedEffort: chatPreferences.selectedEffort
    property string activityMode: chatPreferences.activityMode === "compact"
        ? "compact" : "detailed"

    onSelectedModelChanged: chatPreferences.selectedModel = selectedModel
    onSelectedEffortChanged: chatPreferences.selectedEffort = selectedEffort
    onActivityModeChanged: chatPreferences.activityMode = activityMode

    property string latestActivityItemId: ""
    property var availableModels: []
    property var supportedEfforts: []
    readonly property var presets: {
        const configuration = JSON.parse(presetsFile.text());
        return configuration && Array.isArray(configuration.presets)
            ? configuration.presets : [];
    }
    readonly property string activePresetName: AiChatLogic.matchingPresetName(
        presets, selectedModel, selectedEffort)
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
    property string currentTitle: "New conversation"
    property string persistedThreadName: ""
    property bool historyVisible: false
    property bool historyLoading: false
    property bool historyLoadingMore: false
    property string historyError: ""
    property string historyNextCursor: ""
    property string historyOperation: ""
    property string historyTargetThreadId: ""
    property var pendingHydrationThread: null
    property var pendingHydrationTurns: []
    property string pendingHydrationCursor: ""
    property var pendingResumedSettings: null
    property bool modelCatalogLoading: false
    property bool exportBusy: false
    property string exportToken: ""
    property string exportStagingName: ""
    property string exportSuggestedName: ""
    property bool exportRestoreShown: false
    property bool artifactSaveBusy: false
    property string artifactSaveToken: ""
    property bool artifactSaveRestoreShown: false
    property var outputPreparationContext: null
    property string outputIndexThreadId: ""
    property var notifiedTerminalTurnIds: []
    property var userInterruptedTurnIds: []
    property bool newChatPending: false
    property bool rebuildConfirmationPending: false
    readonly property string rebuildConfirmationNotice: "Rebuild deletes all chat history and generated files. Run /rebuild again to confirm."
    property bool codexAuthorized: false
    property bool syncingChatKit: false
    property bool codexUpdating: false
    property bool codexUpdateRequested: false
    property bool rebuildingSandbox: false
    property bool rebuildRequested: false
    property string maintenanceNotice: ""
    property string pendingMaintenanceNotice: ""
    readonly property bool maintenanceStatusVisible: newChatPending
        || pendingResumedSettings !== null || rebuildingSandbox
        || modelCatalogLoading
        || codexUpdating || syncingChatKit || maintenanceNotice.length > 0
    readonly property bool conversationStarted: messageModel.count > 0
        || submissionStarting || isGenerating
    readonly property alias messages: messageModel
    readonly property alias pendingAttachments: attachmentModel
    readonly property alias historyThreads: historyModel
    readonly property alias artifacts: artifactModel
    readonly property bool attachmentsBusy: screenshot.state === "preparing"
        || screenshot.state === "selecting"
        || screenshot.state === "importing"
        || screenshot.state === "validating"
        || screenshot.state === "capturing"
        || screenshot.state === "copying"
    readonly property bool historyBusy: historyLoading || historyLoadingMore
        || historyOperation.length > 0
    readonly property bool incompatibleActionRunning: attachmentsBusy
        || submissionStarting || isGenerating || newChatPending
        || pendingResumedSettings !== null || sandboxSetupRunning
        || modelCatalogLoading
        || syncingChatKit || codexUpdating || rebuildingSandbox
        || historyBusy || exportBusy || artifactSaveBusy
        || prepareThreadOutputs.running || outputIndex.running
        || cleanupThreadOutputs.running
    readonly property bool canOpenHistory: transport.ready
        && attachmentModel.count === 0 && !incompatibleActionRunning
    readonly property bool canExport: messageModel.count > 0
        && !incompatibleActionRunning
    readonly property bool canSaveArtifacts: transport.ready
        && !incompatibleActionRunning
    readonly property string attachmentState: screenshot.state
    readonly property string attachmentFailureStage: screenshot.failureStage

    signal focusComposer()
    signal threadRenameSucceeded(string threadId)
    signal threadDeleteSucceeded(string threadId)

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
        if (newChatPending) {
            return "Stopping current response…";
        }
        if (pendingResumedSettings !== null) {
            return "Loading conversation settings…";
        }
        if (modelCatalogLoading) {
            return "Loading model catalog…";
        }
        if (maintenanceNotice.length > 0) {
            return maintenanceNotice;
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

    function choosePreset(name) {
        const preset = AiChatLogic.presetByName(presets, name);
        if (preset === null) {
            lastError = "Unknown preset. Type /preset to see configured presets.";
            return false;
        }

        const presetName = String(preset.name || name).trim();
        const presetModel = String(preset.model || "").trim();
        const thinking = String(preset.thinking || "").trim().toLowerCase();
        const model = AiChatLogic.modelById(availableModels, presetModel);
        if (model === null) {
            lastError = "Preset \"" + presetName + "\" uses unknown model \""
                + presetModel + "\".";
            return false;
        }
        if (thinking.length === 0 || model.efforts.indexOf(thinking) < 0) {
            lastError = "Preset \"" + presetName
                + "\" uses unsupported thinking level \"" + thinking + "\".";
            return false;
        }

        chooseModel(model.id);
        chooseEffort(thinking);
        return true;
    }

    function chooseActivityMode(mode) {
        const requested = String(mode || "").toLowerCase();
        if (requested !== "detailed" && requested !== "compact") {
            lastError = "Unknown activity mode. Use /activity detailed or /activity compact.";
            return false;
        }
        activityMode = requested;
        lastError = "";
        return true;
    }

    function applyPendingResumedSettings(catalogComplete) {
        if (pendingResumedSettings === null) {
            return true;
        }

        const settings = pendingResumedSettings;
        const model = AiChatLogic.modelById(
            availableModels, settings.model);
        if (model === null) {
            if (catalogComplete) {
                selectedModel = "";
                selectedModelName = settings.model || "Codex";
                selectedEffort = "default";
                supportedEfforts = [];
                pendingResumedSettings = null;
                diagnosticText = "The resumed model is absent from the model catalog.";
            }
            return false;
        }

        chooseModel(model.id);
        const resumedEffort = String(settings.reasoningEffort || "");
        const effortSupported = resumedEffort.length > 0
            && supportedEfforts.indexOf(resumedEffort) >= 0;
        selectedEffort = effortSupported ? resumedEffort : "default";
        if (resumedEffort.length > 0 && !effortSupported) {
            diagnosticText = "The resumed reasoning effort is absent from the model catalog.";
        }
        pendingResumedSettings = null;
        return true;
    }

    function rememberResumedSettings(payload) {
        pendingResumedSettings = {
            model: String(payload && payload.model || ""),
            reasoningEffort: String(
                payload && payload.reasoningEffort || "")
        };
        applyPendingResumedSettings(!modelCatalogLoading);
    }

    function updateModels(payload) {
        const models = AiChatLogic.modelsFromPayload(payload);
        availableModels = models;
        if (models.length === 0) {
            applyPendingResumedSettings(true);
            return;
        }
        let active = AiChatLogic.modelById(models, selectedModel);
        if (active === null) {
            active = models.find(model => model.isDefault) || models[0];
        }
        chooseModel(active.id);
        applyPendingResumedSettings(true);
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
        const requiresArgument = command === "/model"
            || command === "/thinking" || command === "/effort"
            || command === "/preset" || command === "/activity";
        if (requiresArgument && argument.length === 0) {
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
        case "/export":
            exportConversation();
            break;
        case "/history":
            openHistory();
            break;
        case "/model":
            chooseModel(argument);
            break;
        case "/thinking":
        case "/effort":
            chooseEffort(argument);
            break;
        case "/preset":
            choosePreset(argument);
            break;
        case "/activity":
            chooseActivityMode(argument);
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

    function exportedAttachments(attachments) {
        const exported = [];
        if (attachments === undefined || attachments === null) {
            return exported;
        }
        const count = attachments.count !== undefined
            ? attachments.count : attachments.length || 0;
        for (let index = 0; index < count; index++) {
            const attachment = attachments.get !== undefined
                ? attachments.get(index) : attachments[index];
            exported.push({
                displayName: String(attachment.displayName || "Attachment")
            });
        }
        return exported;
    }

    function conversationExportMessages() {
        const exported = [];
        for (let index = 0; index < messageModel.count; index++) {
            const message = messageModel.get(index);
            if (message.role !== "user" && message.role !== "assistant") {
                continue;
            }
            exported.push({
                role: message.role,
                body: message.body,
                attachments: exportedAttachments(message.attachments)
            });
        }
        return exported;
    }

    function exportConversation() {
        if (!canExport) {
            lastError = messageModel.count === 0
                ? "There is no conversation to export yet."
                : "Wait for the current chat operation to finish before exporting.";
            return;
        }

        const exportedAt = new Date();
        const token = Date.now().toString(36) + "-"
            + Math.floor(Math.random() * 0x1000000).toString(36);
        exportToken = token;
        exportStagingName = ".ai-export-" + token + ".md";
        exportSuggestedName = AiChatLogic.sanitizedExportFilename(
            currentTitle, exportedAt);
        exportRestoreShown = shown;
        exportBusy = true;
        const markdown = AiChatLogic.conversationMarkdown(
            currentTitle, exportedAt, conversationExportMessages());
        Qt.callLater(() => {
            if (root.exportBusy && root.exportToken === token) {
                exportStagingFile.setText(markdown);
            }
        });
    }

    function launchExportDialog() {
        if (!exportBusy || exportStagingName.length === 0
                || exportDialog.running) {
            return;
        }
        shown = false;
        exportDialog.command = [
            "python3", Quickshell.shellPath("ai-chat/AiFileDialog.py"), "export",
            AiConfig.exportStagingDirectory, exportStagingName,
            exportSuggestedName,
            exportToken
        ];
        exportDialog.running = true;
    }

    function finishExport(token, result, message) {
        if (!exportBusy || token !== exportToken) {
            return;
        }
        const restoreShown = exportRestoreShown;
        exportBusy = false;
        exportToken = "";
        exportStagingName = "";
        exportSuggestedName = "";
        exportRestoreShown = false;
        if (result === "completed") {
            lastError = "";
            showMaintenanceNotice("Conversation exported");
        } else if (result === "failed") {
            lastError = String(message || "Could not export the conversation.");
        }
        if (restoreShown) {
            shown = true;
            Qt.callLater(() => focusComposer());
        }
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
            if (latestActivityItemId === "turn:" + currentTurnId) {
                latestActivityItemId = "";
            }
            messageModel.remove(index);
        }
    }

    function appendTurnPlaceholder() {
        const index = appendMessage("activity", "", "streaming", currentThreadId,
            currentTurnId, "turn:" + currentTurnId, []);
        messageModel.setProperty(index, "activityType", "turn");
        messageModel.setProperty(index, "activityTitle", "Thinking");
        latestActivityItemId = "turn:" + currentTurnId;
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
            || modelCatalogLoading || pendingResumedSettings !== null
            || rebuildingSandbox || historyBusy || exportBusy
            || artifactSaveBusy || prepareThreadOutputs.running
            || outputIndex.running || cleanupThreadOutputs.running;
    }

    function requestCodexUpdate() {
        if (maintenanceBlocked()) {
            lastError = "Wait for the current chat operation to finish before updating Codex.";
            return;
        }
        rebuildConfirmationPending = false;
        rebuildConfirmationTimer.stop();
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
        latestActivityItemId = "";
        currentTitle = "New conversation";
        persistedThreadName = "";
        queuedSubmission = null;
        submissionStarting = false;
        isGenerating = false;
        captureRequested = false;
        pendingRequests = {};
        historyVisible = false;
        historyLoading = false;
        historyLoadingMore = false;
        historyError = "";
        historyNextCursor = "";
        historyOperation = "";
        historyTargetThreadId = "";
        pendingHydrationThread = null;
        pendingHydrationTurns = [];
        pendingHydrationCursor = "";
        pendingResumedSettings = null;
        modelCatalogLoading = false;
        newChatPending = false;
        clearConversationFiles();
        clearAttachments();
        messageModel.clear();
        historyModel.clear();
        artifactModel.clear();
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
        if (!rebuildConfirmationPending) {
            rebuildConfirmationPending = true;
            maintenanceNoticeTimer.stop();
            maintenanceNotice = rebuildConfirmationNotice;
            rebuildConfirmationTimer.restart();
            return;
        }

        rebuildConfirmationPending = false;
        rebuildConfirmationTimer.stop();
        maintenanceNotice = "";
        clearConversationForRebuild();
        transport.stop();
        codexAuthorized = false;
        codexUpdateRequested = true;
        rebuildRequested = true;
        pendingMaintenanceNotice = "Sandbox rebuilt; history and generated files were deleted";
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

    function historyThreadIndex(threadId) {
        for (let index = 0; index < historyModel.count; index++) {
            if (historyModel.get(index).threadId === threadId) {
                return index;
            }
        }
        return -1;
    }

    function openHistory() {
        if (!canOpenHistory || attachmentModel.count > 0) {
            lastError = attachmentModel.count > 0
                ? "Remove or send pending attachments before opening history."
                : "Wait for the current chat operation to finish before opening history.";
            return;
        }
        historyVisible = true;
        loadHistory(true);
    }

    function closeHistory() {
        historyVisible = false;
        Qt.callLater(() => focusComposer());
    }

    function loadHistory(reset) {
        if (!transport.ready || historyLoading || historyLoadingMore
                || historyOperation.length > 0) {
            return;
        }
        if (!reset && historyNextCursor.length === 0) {
            return;
        }

        if (reset) {
            historyLoading = true;
            historyError = "";
        } else {
            historyLoadingMore = true;
        }
        const params = {
            cwd: AiConfig.sandboxWorkingDirectory,
            limit: 20,
            sortKey: "updated_at",
            sortDirection: "desc",
            // The umbrella `codex app-server` currently records its sessions
            // as vscode; appServer covers the dedicated server binary.
            sourceKinds: ["appServer", "vscode"]
        };
        if (!reset) {
            params.cursor = historyNextCursor;
        }
        if (call("thread/list", params, "threadList", { reset: reset }) < 0) {
            historyLoading = false;
            historyLoadingMore = false;
            historyError = "Could not load conversation history.";
        }
    }

    function appendHistoryThread(thread) {
        const threadId = String(thread && thread.id || "");
        if (threadId.length === 0 || historyThreadIndex(threadId) >= 0) {
            return;
        }
        historyModel.append({
            threadId: threadId,
            title: AiChatLogic.threadTitle(thread),
            updatedText: AiChatLogic.historyUpdatedText(
                thread.updatedAt, Date.now()),
            statusText: AiChatLogic.threadStatusText(thread.status)
        });
    }

    function resumeThread(threadId) {
        const requestedThreadId = String(threadId || "");
        if (requestedThreadId.length === 0 || incompatibleActionRunning
                || attachmentModel.count > 0) {
            lastError = "Wait for the current chat operation to finish before switching conversations.";
            return;
        }
        if (requestedThreadId === currentThreadId) {
            closeHistory();
            return;
        }

        historyOperation = "resume";
        historyTargetThreadId = requestedThreadId;
        historyError = "";
        const requestId = call("thread/resume", {
            threadId: requestedThreadId,
            cwd: AiConfig.sandboxWorkingDirectory,
            approvalPolicy: "never",
            sandbox: "danger-full-access",
            initialTurnsPage: {
                limit: 50,
                sortDirection: "asc",
                itemsView: "full"
            }
        }, "threadResume", {
            source: "history",
            targetThreadId: requestedThreadId
        });
        if (requestId < 0) {
            historyOperation = "";
            historyTargetThreadId = "";
        }
    }

    function renameThread(threadId, name) {
        const requestedThreadId = String(threadId || "");
        const requestedName = String(name || "")
            .replace(/[\r\n\t]+/g, " ").trim();
        if (requestedThreadId.length === 0 || requestedName.length === 0) {
            historyError = "Enter a conversation name.";
            return;
        }
        if (requestedName.length > 120) {
            historyError = "Conversation names are limited to 120 characters.";
            return;
        }
        if (incompatibleActionRunning) {
            historyError = "Wait for the current chat operation to finish.";
            return;
        }

        historyOperation = "rename";
        historyTargetThreadId = requestedThreadId;
        historyError = "";
        if (call("thread/name/set", {
            threadId: requestedThreadId,
            name: requestedName
        }, "threadRename", {
            threadId: requestedThreadId,
            name: requestedName
        }) < 0) {
            historyOperation = "";
            historyTargetThreadId = "";
        }
    }

    function deleteThread(threadId) {
        const requestedThreadId = String(threadId || "");
        if (requestedThreadId.length === 0 || incompatibleActionRunning) {
            historyError = "Wait for the current chat operation to finish.";
            return;
        }

        historyOperation = "delete";
        historyTargetThreadId = requestedThreadId;
        historyError = "";
        if (call("thread/delete", {
            threadId: requestedThreadId
        }, "threadDelete", {
            threadId: requestedThreadId
        }) < 0) {
            historyOperation = "";
            historyTargetThreadId = "";
        }
    }

    function removeHistoryThread(threadId) {
        const index = historyThreadIndex(threadId);
        if (index >= 0) {
            historyModel.remove(index);
        }
    }

    function clearLoadedConversation() {
        conversationGeneration++;
        currentThreadId = "";
        currentTurnId = "";
        latestActivityItemId = "";
        currentTitle = "New conversation";
        persistedThreadName = "";
        queuedSubmission = null;
        submissionStarting = false;
        isGenerating = false;
        pendingResumedSettings = null;
        newChatPending = false;
        clearConversationFiles();
        clearAttachments();
        messageModel.clear();
        artifactModel.clear();
        screenshot.discard();
        if (transport.state === "streaming") {
            transport.state = "ready";
        }
    }

    function rememberTerminalTurnId(turnId) {
        const requestedTurnId = String(turnId || "");
        if (requestedTurnId.length === 0
                || notifiedTerminalTurnIds.indexOf(requestedTurnId) >= 0) {
            return false;
        }
        notifiedTerminalTurnIds = notifiedTerminalTurnIds
            .concat([requestedTurnId]).slice(-128);
        return true;
    }

    function hydrationTurnsFromResponse(payload, thread) {
        const initialPage = payload && payload.initialTurnsPage || null;
        if (initialPage !== null && Array.isArray(initialPage.data)) {
            return {
                data: initialPage.data,
                nextCursor: String(initialPage.nextCursor || "")
            };
        }
        return {
            data: Array.isArray(thread.turns) ? thread.turns : [],
            nextCursor: ""
        };
    }

    function beginThreadHydration(payload) {
        const thread = payload && payload.thread || {};
        const threadId = String(thread.id || historyTargetThreadId
            || currentThreadId);
        if (threadId.length === 0) {
            historyOperation = "";
            historyTargetThreadId = "";
            pendingResumedSettings = null;
            lastError = "Codex resumed a conversation without a thread ID.";
            return;
        }

        const page = hydrationTurnsFromResponse(payload, thread);
        pendingHydrationThread = thread;
        pendingHydrationTurns = page.data.slice();
        pendingHydrationCursor = page.nextCursor;
        if (pendingHydrationCursor.length > 0) {
            const requestId = call("thread/turns/list", {
                threadId: threadId,
                cursor: pendingHydrationCursor,
                limit: 50,
                sortDirection: "asc",
                itemsView: "full"
            }, "threadTurnsList", { threadId: threadId });
            if (requestId < 0) {
                pendingHydrationThread = null;
                pendingHydrationTurns = [];
                pendingHydrationCursor = "";
                historyOperation = "";
                historyTargetThreadId = "";
            }
            return;
        }
        finishThreadHydration();
    }

    function finishThreadHydration() {
        const thread = pendingHydrationThread || {};
        const threadId = String(thread.id || historyTargetThreadId
            || currentThreadId);
        if (threadId.length === 0) {
            historyOperation = "";
            historyTargetThreadId = "";
            pendingResumedSettings = null;
            return;
        }

        clearConversationFiles();
        clearAttachments();
        screenshot.discard();
        conversationGeneration++;
        currentThreadId = threadId;
        persistedThreadName = String(thread.name || "");
        currentTitle = AiChatLogic.threadTitle(thread);
        messageModel.clear();
        const hydrated = AiChatLogic.messagesFromTurns(
            pendingHydrationTurns, threadId);
        for (const message of hydrated) {
            messageModel.append(message);
        }

        currentTurnId = "";
        latestActivityItemId = "";
        isGenerating = false;
        for (const turn of pendingHydrationTurns) {
            const turnId = String(turn && turn.id || "");
            const status = String(turn && turn.status || "");
            if (status === "inProgress") {
                currentTurnId = turnId;
                isGenerating = true;
            } else {
                rememberTerminalTurnId(turnId);
            }
        }
        if (isGenerating) {
            transport.state = "streaming";
            for (let index = messageModel.count - 1; index >= 0; index--) {
                const message = messageModel.get(index);
                if (message.turnId === currentTurnId
                        && message.role === "activity") {
                    latestActivityItemId = message.itemId;
                    break;
                }
            }
        } else {
            transport.state = "ready";
        }

        pendingHydrationThread = null;
        pendingHydrationTurns = [];
        pendingHydrationCursor = "";
        historyOperation = "";
        historyTargetThreadId = "";
        historyVisible = false;
        lastError = "";
        publishPendingMaintenanceNotice();
        artifactModel.clear();
        if (!prepareOutputsForThread(threadId, { kind: "resumeRefresh" })) {
            lastError = "Could not prepare the private generated-file area.";
            refreshArtifacts();
        }
        Qt.callLater(() => focusComposer());
    }

    function prepareOutputsForThread(threadId, context) {
        const requestedThreadId = String(threadId || "");
        if (requestedThreadId.length === 0 || prepareThreadOutputs.running) {
            return false;
        }
        outputPreparationContext = Object.assign({
            threadId: requestedThreadId
        }, context || {});
        prepareThreadOutputs.command = [
            "bash", Quickshell.shellPath("ai-chat/AiPrepareOutputs.sh"),
            resolvedSandboxName, AiConfig.sandboxWorkspace, requestedThreadId
        ];
        prepareThreadOutputs.running = true;
        return true;
    }

    function refreshArtifacts() {
        if (currentThreadId.length === 0) {
            artifactModel.clear();
            return;
        }
        if (outputIndex.running) {
            return;
        }
        outputIndexThreadId = currentThreadId;
        outputIndex.command = [
            "python3", Quickshell.shellPath("ai-chat/AiOutputs.py"), "index",
            AiConfig.sandboxOutputHostDirectory, currentThreadId
        ];
        outputIndex.running = true;
    }

    function formatFileSize(byteCount) {
        const bytes = Number(byteCount || 0);
        if (bytes < 1024) {
            return bytes + " B";
        }
        if (bytes < 1024 * 1024) {
            return (bytes / 1024).toFixed(bytes < 10240 ? 1 : 0) + " KiB";
        }
        return (bytes / (1024 * 1024)).toFixed(
            bytes < 10 * 1024 * 1024 ? 1 : 0) + " MiB";
    }

    function artifactIndex(relativePath) {
        for (let index = 0; index < artifactModel.count; index++) {
            if (artifactModel.get(index).relativePath === relativePath) {
                return index;
            }
        }
        return -1;
    }

    function saveArtifact(relativePath) {
        const requestedPath = String(relativePath || "");
        if (!canSaveArtifacts || artifactIndex(requestedPath) < 0) {
            lastError = "Wait for the current chat operation to finish before saving a file.";
            return;
        }
        artifactSaveToken = Date.now().toString(36) + "-"
            + Math.floor(Math.random() * 0x1000000).toString(36);
        artifactSaveRestoreShown = shown;
        artifactSaveBusy = true;
        artifactSaveDialog.command = [
            "python3", Quickshell.shellPath("ai-chat/AiFileDialog.py"), "artifact",
            AiConfig.sandboxWorkspace, currentThreadId, requestedPath,
            artifactSaveToken
        ];
        shown = false;
        artifactSaveDialog.running = true;
    }

    function finishArtifactSave(token, result, message) {
        if (!artifactSaveBusy || token !== artifactSaveToken) {
            return;
        }
        const restoreShown = artifactSaveRestoreShown;
        artifactSaveBusy = false;
        artifactSaveToken = "";
        artifactSaveRestoreShown = false;
        if (result === "completed") {
            lastError = "";
            showMaintenanceNotice("Generated file saved");
        } else if (result === "failed") {
            lastError = String(message || "Could not save the generated file.");
        }
        if (restoreShown) {
            shown = true;
            Qt.callLater(() => focusComposer());
        }
    }

    function notificationTitle() {
        const title = persistedThreadName.replace(/[\r\n\t]+/g, " ").trim();
        const visibleTitle = title.length > 0
            ? title.slice(0, 120) : "Quick Chat conversation";
        return visibleTitle.replace(/&/g, "&amp;")
            .replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function notifyResponseReady(turnId, status) {
        const requestedTurnId = String(turnId || "");
        const firstTerminalEvent = rememberTerminalTurnId(requestedTurnId);
        const userInterrupted = userInterruptedTurnIds
            .indexOf(requestedTurnId) >= 0;
        userInterruptedTurnIds = userInterruptedTurnIds.filter(
            candidate => candidate !== requestedTurnId);
        if (!firstTerminalEvent || shown || status !== "completed"
                || userInterrupted) {
            return;
        }
        Quickshell.execDetached({
            command: [
                "bash", Quickshell.shellPath("ai-chat/AiNotifyResponse.sh"),
                notificationTitle()
            ]
        });
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

    function finishNewChat() {
        if (overloadRetry.pending !== null
                && overloadRetry.pending.context.generation !== undefined) {
            overloadRetry.stop();
            overloadRetry.pending = null;
        }
        captureRequested = false;
        historyVisible = false;
        clearLoadedConversation();
        lastError = "";
        focusComposer();
    }

    function newChat() {
        if (attachmentsBusy) {
            shown = true;
            lastError = "Wait for the screenshot operation to finish or discard it.";
            return;
        }
        if (newChatPending) {
            return;
        }
        if (!isGenerating && incompatibleActionRunning) {
            lastError = "Wait for the current chat operation before creating a new chat.";
            return;
        }

        if (isGenerating) {
            newChatPending = true;
            lastError = "";
            if (!stop()) {
                newChatPending = false;
                if (lastError.length === 0) {
                    lastError = "Could not stop the current response.";
                }
            }
            return;
        }
        finishNewChat();
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

    function send(text) {
        const prompt = text.trim();
        if (historyVisible || incompatibleActionRunning) {
            return false;
        }
        if (prompt.length === 0 && attachmentModel.count === 0) {
            lastError = "Write a message or attach a file first.";
            return false;
        }
        if (!transport.ready) {
            lastError = "Codex is still connecting. Your draft has been preserved.";
            if (connectionState === "disconnected" || connectionState === "error") {
                startBackend();
            }
            return false;
        }

        const attachments = [];
        for (let index = 0; index < attachmentModel.count; index++) {
            const attachment = attachmentModel.get(index);
            if (attachment.status !== "ready") {
                lastError = "Wait for the attachment to finish copying, or remove it.";
                return false;
            }
            attachments.push({
                token: attachment.token,
                hostPath: attachment.hostPath,
                sandboxPath: attachment.sandboxPath,
                kind: attachment.attachmentKind,
                displayName: attachment.displayName
            });
        }
        queuedSubmission = {
            text: prompt,
            attachments: attachments,
            optimisticMessageId: ""
        };
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
            const requestId = call("thread/start", threadParams, "threadStart",
                { generation: conversationGeneration });
            if (requestId < 0) {
                queuedSubmission = null;
                return false;
            }
        } else if (!prepareOutputsForThread(currentThreadId,
                { kind: "turnStart" })) {
            submissionStarting = false;
            queuedSubmission = null;
            lastError = "Could not prepare the managed output area.";
            return false;
        }
        const firstMessage = messageModel.count === 0;
        const messageIndex = appendMessage("user", prompt, "sending",
            currentThreadId, "", "", attachments);
        const submission = Object.assign({}, queuedSubmission, {
            optimisticMessageId: messageModel.get(messageIndex).messageId
        });
        queuedSubmission = submission;
        if (firstMessage && prompt.length > 0) {
            const fallbackTitle = prompt.replace(/[\r\n\t]+/g, " ").trim();
            currentTitle = fallbackTitle.length > 48
                ? fallbackTitle.slice(0, 48) + "…" : fallbackTitle;
        }
        return true;
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
            input.push({
                type: "text",
                text: AiChatLogic.attachmentMetadataInput(
                    attachment.kind, attachment.displayName,
                    attachment.sandboxPath)
            });
            if (attachment.kind === "image") {
                input.push({ type: "localImage", path: attachment.sandboxPath });
            }
        }
        const submission = queuedSubmission;
        const requestId = call("turn/start", modelSettings({
            threadId: currentThreadId,
            input: input,
            cwd: AiConfig.sandboxWorkingDirectory,
            approvalPolicy: "never",
            sandboxPolicy: { type: "dangerFullAccess" }
        }), "turnStart", {
            submission: submission,
            generation: conversationGeneration
        });
        if (requestId < 0) {
            failSubmission(submission, lastError);
        }
    }

    function stop() {
        if (!isGenerating || currentThreadId.length === 0
                || currentTurnId.length === 0) {
            return false;
        }
        const interruptedTurnId = currentTurnId;
        const requestId = call("turn/interrupt", {
            threadId: currentThreadId,
            turnId: interruptedTurnId
        }, "interrupt", {
            generation: conversationGeneration,
            turnId: interruptedTurnId
        });
        if (requestId < 0) {
            return false;
        }
        if (userInterruptedTurnIds.indexOf(interruptedTurnId) < 0) {
            userInterruptedTurnIds = userInterruptedTurnIds
                .concat([interruptedTurnId]).slice(-128);
        }
        return true;
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

    function submissionMessageIndex(submission) {
        const messageId = String(
            submission && submission.optimisticMessageId || "");
        if (messageId.length === 0) {
            return -1;
        }
        for (let index = messageModel.count - 1; index >= 0; index--) {
            if (messageModel.get(index).messageId === messageId) {
                return index;
            }
        }
        return -1;
    }

    function failSubmission(submission, message) {
        const index = submissionMessageIndex(submission);
        if (index < 0) {
            return;
        }
        messageModel.setProperty(index, "messageStatus", "failed");
        messageModel.setProperty(index, "errorText", String(message
            || "Codex could not send this message."));
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
            return;
        }

        if (!succeeded) {
            if (pending.kind === "modelList") {
                modelCatalogLoading = false;
                diagnosticText = "Codex did not provide a model catalog.";
                applyPendingResumedSettings(true);
                return;
            }
            if (Number(payload.code) === -32001 && pending.retryCount < 3) {
                overloadRetry.pending = pending;
                overloadRetry.interval = 500 + Math.floor(Math.random() * 350);
                overloadRetry.restart();
                return;
            }

            if (pending.kind === "initialize" || pending.kind === "accountRead") {
                transport.state = "error";
                lastError = "Could not initialize Codex.";
            } else if (pending.kind === "threadList") {
                historyLoading = false;
                historyLoadingMore = false;
                historyError = "Could not load conversation history.";
                lastError = historyError;
            } else if (pending.kind === "threadResume"
                    || pending.kind === "threadTurnsList") {
                pendingHydrationThread = null;
                pendingHydrationTurns = [];
                pendingHydrationCursor = "";
                historyOperation = "";
                historyTargetThreadId = "";
                pendingResumedSettings = null;
                historyError = "Could not resume the conversation.";
                lastError = historyError;
                transport.state = "ready";
            } else if (pending.kind === "threadRename") {
                historyOperation = "";
                historyTargetThreadId = "";
                historyError = "Could not rename the conversation.";
                lastError = historyError;
            } else if (pending.kind === "threadDelete") {
                historyOperation = "";
                historyTargetThreadId = "";
                historyError = "Could not delete the conversation.";
                lastError = historyError;
            } else if (pending.kind === "interrupt") {
                const failedTurnId = String(pending.context.turnId || "");
                userInterruptedTurnIds = userInterruptedTurnIds.filter(
                    candidate => candidate !== failedTurnId);
                newChatPending = false;
                lastError = "Could not stop the current response.";
            } else {
                lastError = "Codex could not complete the chat operation.";
            }
            submissionStarting = false;
            if (pending.kind === "turnStart") {
                queuedSubmission = pending.context.submission;
            }
            if (pending.kind === "threadStart"
                    || pending.kind === "turnStart") {
                failSubmission(queuedSubmission, lastError);
            }
            return;
        }

        if (pending.kind === "initialize") {
            transport.notify("initialized", {});
            call("account/read", { refreshToken: false }, "accountRead", {});
        } else if (pending.kind === "accountRead") {
            const requiresOpenaiAuth = payload
                && payload.requiresOpenaiAuth === true;
            if (requiresOpenaiAuth) {
                codexAuthorized = false;
                transport.state = "error";
                lastError = "Codex authentication is unavailable. Configure credentials for the sbx Codex agent.";
                pendingMaintenanceNotice = "";
            } else {
                codexAuthorized = true;
                transport.reconnectAttempt = 0;
                modelCatalogLoading = true;
                if (call("model/list", {
                    limit: 100,
                    includeHidden: false
                }, "modelList", {}) < 0) {
                    modelCatalogLoading = false;
                    diagnosticText = "Codex did not provide a model catalog.";
                    applyPendingResumedSettings(true);
                }
                if (currentThreadId.length > 0) {
                    call("thread/resume", {
                        threadId: currentThreadId,
                        cwd: AiConfig.sandboxWorkingDirectory,
                        approvalPolicy: "never",
                        sandbox: "danger-full-access",
                        initialTurnsPage: {
                            limit: 50,
                            sortDirection: "asc",
                            itemsView: "full"
                        }
                    }, "threadResume", {
                        source: "reconnect",
                        targetThreadId: currentThreadId,
                        generation: conversationGeneration
                    });
                } else {
                    transport.state = "ready";
                    publishPendingMaintenanceNotice();
                }
            }
        } else if (pending.kind === "modelList") {
            modelCatalogLoading = false;
            updateModels(payload);
        } else if (pending.kind === "threadList") {
            const threads = Array.isArray(payload.data) ? payload.data : [];
            if (pending.context.reset) {
                historyModel.clear();
            }
            for (const thread of threads) {
                appendHistoryThread(thread);
            }
            historyNextCursor = String(payload.nextCursor || "");
            historyLoading = false;
            historyLoadingMore = false;
            historyError = "";
        } else if (pending.kind === "threadResume") {
            rememberResumedSettings(payload);
            beginThreadHydration(payload);
        } else if (pending.kind === "threadTurnsList") {
            const turns = Array.isArray(payload.data) ? payload.data : [];
            pendingHydrationTurns = pendingHydrationTurns.concat(turns);
            pendingHydrationCursor = String(payload.nextCursor || "");
            if (pendingHydrationCursor.length > 0) {
                const nextRequest = call("thread/turns/list", {
                    threadId: pending.context.threadId,
                    cursor: pendingHydrationCursor,
                    limit: 50,
                    sortDirection: "asc",
                    itemsView: "full"
                }, "threadTurnsList", {
                    threadId: pending.context.threadId
                });
                if (nextRequest < 0) {
                    pendingHydrationThread = null;
                    pendingHydrationTurns = [];
                    pendingHydrationCursor = "";
                    historyOperation = "";
                    historyTargetThreadId = "";
                }
            } else {
                finishThreadHydration();
            }
        } else if (pending.kind === "threadStart") {
            currentThreadId = String(payload.thread
                ? payload.thread.id : payload.threadId || "");
            if (currentThreadId.length === 0) {
                submissionStarting = false;
                lastError = "Codex did not return a thread ID.";
                failSubmission(queuedSubmission, lastError);
                return;
            }
            persistedThreadName = "";
            if (!prepareOutputsForThread(currentThreadId,
                    { kind: "turnStart" })) {
                submissionStarting = false;
                queuedSubmission = null;
                lastError = "Could not prepare the managed output area.";
            }
        } else if (pending.kind === "turnStart") {
            const turn = payload.turn || {};
            currentTurnId = String(turn.id || payload.turnId || "");
            const submission = pending.context.submission;
            currentTurnAttachments = submission.attachments;
            const submittedHostPaths = submission.attachments
                .map(item => item.hostPath);
            conversationHostFiles = conversationHostFiles
                .concat(submittedHostPaths);
            const userMessageIndex = submissionMessageIndex(submission);
            if (userMessageIndex >= 0) {
                messageModel.setProperty(
                    userMessageIndex, "threadId", currentThreadId);
                messageModel.setProperty(
                    userMessageIndex, "turnId", currentTurnId);
                messageModel.setProperty(
                    userMessageIndex, "messageStatus", "completed");
                messageModel.setProperty(userMessageIndex, "errorText", "");
            } else {
                appendMessage("user", submission.text, "completed",
                    currentThreadId, currentTurnId, "", submission.attachments);
            }
            appendTurnPlaceholder();
            queuedSubmission = null;
            submissionStarting = false;
            isGenerating = true;
            transport.state = "streaming";
            attachmentModel.clear();
        } else if (pending.kind === "threadRename") {
            const threadId = pending.context.threadId;
            const index = historyThreadIndex(threadId);
            if (index >= 0) {
                historyModel.setProperty(index, "title", pending.context.name);
            }
            if (threadId === currentThreadId) {
                persistedThreadName = pending.context.name;
                currentTitle = pending.context.name;
            }
            historyOperation = "";
            historyTargetThreadId = "";
            historyError = "";
            lastError = "";
            threadRenameSucceeded(threadId);
        } else if (pending.kind === "threadDelete") {
            const threadId = pending.context.threadId;
            removeHistoryThread(threadId);
            if (threadId === currentThreadId) {
                clearLoadedConversation();
            }
            historyOperation = "";
            historyTargetThreadId = "";
            historyError = "";
            lastError = "";
            cleanupThreadOutputs.command = [
                "python3", Quickshell.shellPath("ai-chat/AiOutputs.py"), "delete",
                AiConfig.sandboxOutputHostDirectory, threadId
            ];
            cleanupThreadOutputs.running = true;
            threadDeleteSucceeded(threadId);
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
                const index = appendActivity(item, "streaming");
                if (index >= 0) {
                    latestActivityItemId = String(item.id || "");
                }
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
            const message = "The Codex turn failed.";
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
            const terminalTurnId = String(turn.id || params.turnId
                || currentTurnId);
            const status = String(turn.status || params.status || "completed");
            const failureMessage = status === "failed"
                ? "The Codex turn failed." : "";
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
                if (entry.turnId !== terminalTurnId
                        || entry.messageStatus !== "streaming") {
                    continue;
                }
                messageModel.setProperty(index, "messageStatus",
                    status === "completed" ? "completed" : status);
                if (entry.role === "assistant" && failureMessage.length > 0) {
                    messageModel.setProperty(index, "errorText", failureMessage);
                }
            }
            notifyResponseReady(terminalTurnId, status);
            if (newChatPending) {
                finishNewChat();
                return;
            }
            currentTurnId = "";
            latestActivityItemId = "";
            refreshArtifacts();
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
    ListModel { id: historyModel }
    ListModel { id: artifactModel }

    TextEdit {
        id: clipboardBuffer
        visible: false
    }

    FileView {
        id: presetsFile

        path: Quickshell.shellPath("ai-chat/AiPresets.json")
        blockLoading: true
    }

    FileView {
        id: preferencesFile

        path: Quickshell.stateDir + "/ai-chat-preferences.json"
        blockLoading: true
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: chatPreferences

            property string selectedModel: ""
            property string selectedEffort: "default"
            property string activityMode: "detailed"
        }
    }

    FileView {
        id: exportStagingFile

        path: root.exportStagingName.length > 0
            ? AiConfig.exportStagingDirectory + "/" + root.exportStagingName : ""
        atomicWrites: true
        printErrors: false
        onSaved: root.launchExportDialog()
        onSaveFailed: {
            const token = root.exportToken;
            const stagingName = root.exportStagingName;
            root.finishExport(token, "failed",
                "Could not prepare the conversation export.");
            if (stagingName.length > 0 && !cleanupExportStaging.running) {
                cleanupExportStaging.command = [
                    "rm", "-f", "--",
                    AiConfig.exportStagingDirectory + "/" + stagingName
                ];
                cleanupExportStaging.running = true;
            }
        }
    }

    Timer {
        id: maintenanceNoticeTimer
        interval: 4000
        onTriggered: root.maintenanceNotice = ""
    }

    Timer {
        id: rebuildConfirmationTimer
        interval: 30000
        onTriggered: {
            root.rebuildConfirmationPending = false;
            if (root.maintenanceNotice === root.rebuildConfirmationNotice) {
                root.maintenanceNotice = "";
            }
        }
    }

    Process {
        id: exportDialog

        stderr: StdioCollector {}
        onExited: {
            if (!root.exportBusy) {
                return;
            }
            const token = root.exportToken;
            const stagingName = root.exportStagingName;
            root.finishExport(token, "failed",
                "The conversation export helper stopped unexpectedly.");
            if (stagingName.length > 0 && !cleanupExportStaging.running) {
                cleanupExportStaging.command = [
                    "rm", "-f", "--",
                    AiConfig.exportStagingDirectory + "/" + stagingName
                ];
                cleanupExportStaging.running = true;
            }
        }
    }

    Process {
        id: cleanupExportStaging
        stderr: StdioCollector {}
    }

    Process {
        id: artifactSaveDialog

        stderr: StdioCollector {}
        onExited: {
            if (root.artifactSaveBusy) {
                root.finishArtifactSave(root.artifactSaveToken, "failed",
                    "The generated-file save helper stopped unexpectedly.");
            }
        }
    }

    Process {
        id: prepareThreadOutputs

        stderr: StdioCollector {}
        onExited: function(exitCode) {
            const context = root.outputPreparationContext || {};
            root.outputPreparationContext = null;
            if (exitCode !== 0) {
                if (context.kind === "turnStart") {
                    root.submissionStarting = false;
                    root.lastError = "Could not prepare the private generated-file area.";
                    root.failSubmission(root.queuedSubmission, root.lastError);
                    root.queuedSubmission = null;
                } else {
                    root.lastError = "Could not prepare the private generated-file area.";
                }
                if (context.kind === "resumeRefresh") {
                    root.refreshArtifacts();
                }
                return;
            }
            if (context.kind === "turnStart") {
                root.startQueuedTurn();
            } else {
                root.refreshArtifacts();
            }
        }
    }

    Process {
        id: outputIndex

        stdout: StdioCollector { id: outputIndexData }
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            const indexedThreadId = root.outputIndexThreadId;
            root.outputIndexThreadId = "";
            if (indexedThreadId !== root.currentThreadId) {
                return;
            }
            if (exitCode !== 0) {
                root.lastError = "Could not inspect generated files.";
                return;
            }

            const indexed = [];
            let parseFailed = false;
            const lines = outputIndexData.text.split(/\r?\n/);
            for (const line of lines) {
                if (line.length === 0) {
                    continue;
                }
                try {
                    const item = JSON.parse(line);
                    const relativePath = String(item.relativePath || "");
                    const components = relativePath.split("/");
                    const size = Number(item.size || 0);
                    if (relativePath.length === 0
                            || relativePath.startsWith("/")
                            || components.indexOf("..") >= 0
                            || !Number.isFinite(size) || size < 0
                            || size > AiConfig.sandboxOutputMaxBytes) {
                        continue;
                    }
                    indexed.push({
                        relativePath: relativePath,
                        size: size,
                        sizeText: root.formatFileSize(size),
                        mimeType: String(item.mimeType || "File")
                    });
                } catch (error) {
                    parseFailed = true;
                    break;
                }
            }
            if (parseFailed) {
                root.lastError = "Could not read the generated-file index.";
                return;
            }
            artifactModel.clear();
            for (const item of indexed) {
                artifactModel.append(item);
            }
        }
    }

    Process {
        id: cleanupThreadOutputs

        stderr: StdioCollector {}
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.lastError = "Conversation deleted, but its generated files could not be removed.";
            }
        }
    }

    Process {
        id: chatKitSync

        command: [
            "bash", Quickshell.shellPath("ai-chat/AiChatKitSync.sh"),
            root.resolvedSandboxName, AiConfig.sandboxWorkspace
        ]
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            root.syncingChatKit = false;
            if (exitCode !== 0) {
                root.pendingMaintenanceNotice = "";
                transport.state = "error";
                root.lastError = "Could not load the AI chat kit into the sandbox.";
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
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            root.codexUpdating = false;
            root.codexUpdateRequested = false;
            if (exitCode !== 0) {
                root.pendingMaintenanceNotice = "";
                root.lastError = "Codex update failed.";
            }
            root.syncChatKit();
        }
    }

    Process {
        id: removeChatSandbox

        command: AiConfig.sbxCommand.concat([
            "rm", "--force", AiConfig.sandboxName
        ])
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            root.rebuildingSandbox = false;
            root.rebuildRequested = false;
            if (exitCode !== 0) {
                root.codexUpdateRequested = false;
                root.pendingMaintenanceNotice = "";
                transport.state = "error";
                root.lastError = "Could not remove the Codex sandbox for rebuilding.";
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
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            sandboxSetupTimeout.stop();
            if (root.sandboxSetupTimedOut) {
                return;
            }
            if (exitCode !== 0) {
                root.failSandboxSetup(
                    "Could not list sbx sandboxes. Run sbx ls in a terminal.");
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

        stderr: StdioCollector {}
        onExited: function(exitCode) {
            sandboxSetupTimeout.stop();
            if (root.sandboxSetupTimedOut) {
                return;
            }
            if (exitCode !== 0) {
                root.failSandboxSetup(
                    "Could not reset the private AI sandbox workspace.");
                return;
            }
            prepareSandboxWorkspace.command = [
                "install", "-d", "-m", "700", "--",
                AiConfig.sandboxWorkspace, AiConfig.sandboxOutputHostDirectory
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
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            sandboxSetupTimeout.stop();
            if (root.sandboxSetupTimedOut) {
                return;
            }
            if (exitCode !== 0) {
                root.failSandboxSetup(
                    "Could not create the dedicated Codex sandbox. Run sbx diagnose, then use /reconnect.");
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
                console.log("AI app-server lifecycle diagnostic");
            }
        }
        onStateChanged: {
            if (state === "initializing") {
                root.modelCatalogLoading = false;
                const updated = {};
                root.pendingRequests = updated;
                root.call("initialize", {
                    clientInfo: {
                        name: "quickshell_ai_chat",
                        title: "Quickshell AI Quick Chat",
                        version: "1.0.0"
                    },
                    capabilities: { experimentalApi: true }
                }, "initialize", {});
            } else if (state === "error") {
                root.codexAuthorized = false;
                root.modelCatalogLoading = false;
                root.pendingResumedSettings = null;
                overloadRetry.stop();
                overloadRetry.pending = null;
                root.historyLoading = false;
                root.historyLoadingMore = false;
                root.historyOperation = "";
                root.historyTargetThreadId = "";
                root.pendingHydrationThread = null;
                root.pendingHydrationTurns = [];
                root.pendingHydrationCursor = "";
                if (root.submissionStarting) {
                    root.submissionStarting = false;
                    root.failSubmission(root.queuedSubmission,
                        root.lastError || "The Codex backend disconnected.");
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
                    root.latestActivityItemId = "";
                }
                if (root.newChatPending) {
                    root.finishNewChat();
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
                root.lastError = "Codex is busy; retry when the backend is ready.";
                root.submissionStarting = false;
                root.failSubmission(root.queuedSubmission, root.lastError);
                root.historyLoading = false;
                root.historyLoadingMore = false;
                root.historyOperation = "";
                root.historyTargetThreadId = "";
                pending = null;
                return;
            }
            const requestId = transport.request(pending.method, pending.params);
            if (requestId < 0) {
                root.submissionStarting = false;
                root.failSubmission(root.queuedSubmission,
                    "Codex is busy; retry when the backend is ready.");
                root.historyLoading = false;
                root.historyLoadingMore = false;
                root.historyOperation = "";
                root.historyTargetThreadId = "";
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
        function history(): void {
            root.open();
            Qt.callLater(() => root.openHistory());
        }
        function exportChat(): void { root.exportConversation(); }
        function exportCompleted(token: string): void {
            root.finishExport(token, "completed", "");
        }
        function exportCancelled(token: string): void {
            root.finishExport(token, "cancelled", "");
        }
        function exportFailed(token: string, message: string): void {
            root.finishExport(token, "failed", message);
        }
        function artifactSaveCompleted(token: string): void {
            root.finishArtifactSave(token, "completed", "");
        }
        function artifactSaveCancelled(token: string): void {
            root.finishArtifactSave(token, "cancelled", "");
        }
        function artifactSaveFailed(token: string, message: string): void {
            root.finishArtifactSave(token, "failed", message);
        }
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
