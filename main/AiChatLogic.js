const COMMAND_CATALOG = [
    {
        label: "/file",
        detail: "Attach an image or text file",
        draft: "/file",
        immediate: true
    },
    {
        label: "/ps",
        detail: "Capture a screen region",
        draft: "/ps",
        immediate: true
    },
    {
        label: "/copy",
        detail: "Copy the entire chat",
        draft: "/copy",
        immediate: true
    },
    {
        label: "/export",
        detail: "Save this conversation as Markdown",
        draft: "/export",
        immediate: true
    },
    {
        label: "/history",
        detail: "Browse saved conversations",
        draft: "/history",
        immediate: true
    },
    {
        label: "/model",
        detail: "Change model",
        draft: "/model ",
        immediate: false
    },
    {
        label: "/thinking",
        detail: "Change thinking level",
        draft: "/thinking ",
        immediate: false
    },
    {
        label: "/activity",
        detail: "Choose detailed or compact activity",
        draft: "/activity ",
        immediate: false
    },
    {
        label: "/new",
        detail: "Start a new chat and keep this conversation",
        draft: "/new",
        immediate: true
    },
    {
        label: "/reconnect",
        detail: "Reload the chat kit and backend",
        draft: "/reconnect",
        immediate: true
    },
    {
        label: "/update",
        detail: "Update Codex and reconnect",
        draft: "/update",
        immediate: true
    },
    {
        label: "/rebuild",
        detail: "Delete all chat history and generated files",
        draft: "/rebuild",
        immediate: true
    }
];

const ATTACHMENT_METADATA_PREFIX = "[[quickshell-ai-attachment:";
const ATTACHMENT_METADATA_SUFFIX = "]]";

function titleCase(value) {
    const text = String(value || "");
    return text.length === 0 ? "" : text.charAt(0).toUpperCase() + text.slice(1);
}

function conciseModelName(value) {
    const name = String(value || "Codex").replace(/^GPT-/i, "");
    return name.replace(/-/g, " ");
}

function modelStatusText(modelName, effortName) {
    const effort = effortName === "" || effortName === "default"
        ? "Auto" : titleCase(effortName);
    return conciseModelName(modelName) + " " + effort;
}

function modelById(models, modelId) {
    const requested = String(modelId || "").toLowerCase();
    for (const model of models) {
        if (String(model.id).toLowerCase() === requested
                || String(model.displayName).toLowerCase() === requested) {
            return model;
        }
    }
    return null;
}

function modelsFromPayload(payload) {
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
    return models;
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

function commandItems(draft, availableModels, selectedModel,
        supportedEfforts, selectedEffort, activityMode) {
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
                detail: effort === selectedEffort
                    ? "Current thinking level" : "Thinking level",
                draft: "/thinking " + effort,
                immediate: true
            }));
    }
    if (lowered.indexOf("/activity") === 0
            && (lowered.length === 9 || lowered.charAt(9) === " ")) {
        const query = lowered.slice(9).trim();
        return [
            {
                label: "Detailed",
                detail: activityMode === "detailed"
                    ? "Current mode — keep thinking and tool cards"
                    : "Keep thinking and tool cards",
                draft: "/activity detailed",
                immediate: true
            },
            {
                label: "Compact",
                detail: activityMode === "compact"
                    ? "Current mode — show only the latest activity"
                    : "Show only the latest activity",
                draft: "/activity compact",
                immediate: true
            }
        ].filter(mode => query.length === 0
            || mode.label.toLowerCase().indexOf(query) >= 0);
    }

    return COMMAND_CATALOG.filter(
        command => command.label.indexOf(lowered) === 0);
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

function normalizedAttachmentName(value, fallback) {
    const name = String(value || fallback || "Attachment")
        .replace(/[\u0000-\u001f\u007f]/g, " ")
        .trim();
    return name.length > 0 ? name.slice(0, 120) : fallback;
}

function attachmentMetadataInput(kind, displayName, sandboxPath) {
    const normalizedKind = kind === "text" ? "text" : "image";
    const metadata = encodeURIComponent(JSON.stringify({
        version: 1,
        kind: normalizedKind,
        displayName: normalizedAttachmentName(
            displayName,
            normalizedKind === "text" ? "Text attachment" : "Image attachment")
    }));
    const marker = ATTACHMENT_METADATA_PREFIX + metadata
        + ATTACHMENT_METADATA_SUFFIX;
    if (normalizedKind === "text") {
        return marker
            + "\nA user-selected text file is available inside the sandbox at "
            + String(sandboxPath || "")
            + ". Read it when relevant to the request.";
    }
    return marker;
}

function attachmentFromMetadataInput(value) {
    const text = String(value || "");
    if (text.indexOf(ATTACHMENT_METADATA_PREFIX) !== 0) {
        return null;
    }
    const suffixIndex = text.indexOf(
        ATTACHMENT_METADATA_SUFFIX, ATTACHMENT_METADATA_PREFIX.length);
    if (suffixIndex < 0) {
        return null;
    }
    try {
        const metadata = JSON.parse(decodeURIComponent(text.slice(
            ATTACHMENT_METADATA_PREFIX.length, suffixIndex)));
        if (!metadata || metadata.version !== 1
                || (metadata.kind !== "text" && metadata.kind !== "image")
                || typeof metadata.displayName !== "string") {
            return null;
        }
        const kind = metadata.kind;
        return {
            attachmentKind: kind,
            displayName: normalizedAttachmentName(
                metadata.displayName,
                kind === "text" ? "Text attachment" : "Image attachment")
        };
    } catch (error) {
        return null;
    }
}

function isLegacyTextAttachmentInput(value) {
    const text = String(value || "");
    return /^A user-selected text file is available inside the sandbox at /.test(text);
}

function persistedMessage(
    role,
    body,
    status,
    threadId,
    turnId,
    itemId,
    attachments,
    createdAt,
    ordinal
) {
    return {
        messageId: String(itemId || turnId + "-" + ordinal),
        role: role,
        body: String(body || ""),
        messageStatus: normalizedActivityStatus(status, "completed"),
        threadId: String(threadId || ""),
        turnId: String(turnId || ""),
        itemId: String(itemId || ""),
        attachments: attachments || [],
        activityType: "",
        activityTitle: "",
        activityOutput: "",
        errorText: "",
        createdAt: createdAt
    };
}

function turnCreatedAt(turn) {
    const startedAt = Number((turn && turn.startedAt) || 0);
    if (!Number.isFinite(startedAt) || startedAt <= 0) {
        return "";
    }
    return new Date(startedAt * 1000).toISOString();
}

function messagesFromTurns(turns, threadId) {
    const messages = [];
    const sourceTurns = Array.isArray(turns) ? turns : [];
    let ordinal = 0;

    for (const turn of sourceTurns) {
        if (!turn) {
            continue;
        }
        const turnId = String(turn.id || "");
        const turnStatus = normalizedActivityStatus(turn.status, "completed");
        const createdAt = turnCreatedAt(turn);
        const items = Array.isArray(turn.items) ? turn.items : [];
        let lastAssistantIndex = -1;
        let hasTurnProgress = false;

        for (const item of items) {
            if (!item) {
                continue;
            }
            const itemType = String(item.type || "");
            const itemId = String(item.id || "");
            if (itemType === "userMessage") {
                const content = Array.isArray(item.content) ? item.content : [];
                const textParts = [];
                const attachments = [];
                const pendingImages = [];

                for (const input of content) {
                    if (!input) {
                        continue;
                    }
                    const inputType = String(input.type || "");
                    if (inputType === "text") {
                        const text = String(input.text || "");
                        const metadata = attachmentFromMetadataInput(text);
                        if (metadata !== null) {
                            if (metadata.attachmentKind === "image") {
                                pendingImages.push(metadata);
                            } else {
                                attachments.push({
                                    hostPath: "",
                                    attachmentKind: "text",
                                    displayName: metadata.displayName
                                });
                            }
                            continue;
                        }
                        if (isLegacyTextAttachmentInput(text)) {
                            attachments.push({
                                hostPath: "",
                                attachmentKind: "text",
                                displayName: "Text attachment"
                            });
                            continue;
                        }
                        textParts.push(text);
                    } else if (inputType === "localImage"
                            || inputType === "image") {
                        const metadata = pendingImages.length > 0
                            ? pendingImages.shift()
                            : {
                                attachmentKind: "image",
                                displayName: "Image attachment"
                            };
                        attachments.push({
                            hostPath: "",
                            attachmentKind: "image",
                            displayName: metadata.displayName
                        });
                    }
                }
                for (const metadata of pendingImages) {
                    attachments.push({
                        hostPath: "",
                        attachmentKind: "image",
                        displayName: metadata.displayName
                    });
                }
                const userBody = textParts.join("\n\n");
                if (userBody.length > 0 || attachments.length > 0) {
                    messages.push(
                        persistedMessage(
                            "user",
                            userBody,
                            "completed",
                            threadId,
                            turnId,
                            itemId,
                            attachments,
                            createdAt,
                            ordinal++
                        )
                    );
                }
                continue;
            }
            if (itemType === "agentMessage") {
                messages.push(
                    persistedMessage(
                        "assistant",
                        item.text || "",
                        turnStatus,
                        threadId,
                        turnId,
                        itemId,
                        [],
                        createdAt,
                        ordinal++
                    )
                );
                lastAssistantIndex = messages.length - 1;
                hasTurnProgress = true;
                continue;
            }
            if (!isActivityItem(item)) {
                continue;
            }

            const activity = persistedMessage(
                "activity",
                activityBody(item),
                normalizedActivityStatus(item.status, turnStatus),
                threadId,
                turnId,
                itemId,
                [],
                createdAt,
                ordinal++
            );
            activity.activityType = itemType;
            activity.activityTitle = activityTitle(item);
            activity.activityOutput = activityOutput(item);
            messages.push(activity);
            hasTurnProgress = true;
        }

        const failure = turn.error || {};
        const failureMessage =
            turnStatus === "failed"
                ? String(failure.message || "The Codex turn failed.").slice(0, 600)
                : "";
        if (failureMessage.length > 0 && lastAssistantIndex >= 0) {
            messages[lastAssistantIndex].errorText = failureMessage;
        } else if (
            (turnStatus === "failed" || turnStatus === "interrupted") &&
            lastAssistantIndex < 0
        ) {
            const terminal = persistedMessage(
                "assistant",
                "",
                turnStatus,
                threadId,
                turnId,
                "",
                [],
                createdAt,
                ordinal++
            );
            terminal.errorText = failureMessage;
            messages.push(terminal);
        } else if (turnStatus === "streaming" && !hasTurnProgress) {
            const placeholder = persistedMessage(
                "activity",
                "",
                "streaming",
                threadId,
                turnId,
                "turn:" + turnId,
                [],
                createdAt,
                ordinal++
            );
            placeholder.activityType = "turn";
            placeholder.activityTitle = "Thinking";
            messages.push(placeholder);
        }
    }
    return messages;
}

function messageCount(messages) {
    if (!messages) {
        return 0;
    }
    const count = Number(messages.count);
    return Number.isFinite(count) ? count : messages.length || 0;
}

function messageAt(messages, index) {
    return typeof messages.get === "function"
        ? messages.get(index) : messages[index];
}

function assistantResponseBody(messages, messageIndex) {
    const selected = messageAt(messages, messageIndex);
    if (!selected || selected.role !== "assistant") {
        return "";
    }
    const turnId = String(selected.turnId || "");
    if (turnId.length === 0) {
        return String(selected.body || "");
    }

    const parts = [];
    for (let index = 0; index < messageCount(messages); index++) {
        const message = messageAt(messages, index);
        if (!message || message.role !== "assistant"
                || String(message.turnId || "") !== turnId) {
            continue;
        }
        const body = String(message.body || "");
        if (body.trim().length > 0) {
            parts.push(body);
        }
    }
    return parts.join("\n\n");
}

function isAssistantResponseTail(messages, messageIndex) {
    const selected = messageAt(messages, messageIndex);
    if (!selected || selected.role !== "assistant") {
        return false;
    }
    const turnId = String(selected.turnId || "");
    if (turnId.length === 0) {
        return true;
    }

    for (let index = messageIndex + 1; index < messageCount(messages); index++) {
        const message = messageAt(messages, index);
        if (message && message.role === "assistant"
                && String(message.turnId || "") === turnId) {
            return false;
        }
    }
    return true;
}

function escapeMarkdownLiteral(value) {
    return String(value || "")
        .replace(/\\/g, "\\\\")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/([`*_{}\[\]()#+.!|>-])/g, "\\$1");
}

function quotedUserMarkdown(value) {
    return String(value || "")
        .split("\n")
        .map(line => line.length > 0
            ? "> " + escapeMarkdownLiteral(line) : ">")
        .join("\n");
}

function conversationMarkdown(title, exportedAt, messages) {
    const safeTitle = escapeMarkdownLiteral(
        String(title || "Conversation")
            .replace(/[\r\n\t]+/g, " ")
            .trim()
    );
    const timestamp = exportedAt instanceof Date
        ? exportedAt.toISOString() : String(exportedAt || "");
    const sections = [
        "# " + (safeTitle.length > 0 ? safeTitle : "Conversation"),
        "_Exported: " + escapeMarkdownLiteral(timestamp) + "_"
    ];

    for (const message of Array.isArray(messages) ? messages : []) {
        if (!message || (message.role !== "user" && message.role !== "assistant")) {
            continue;
        }
        const body = String(message.body || "");
        const attachments = Array.isArray(message.attachments)
            ? message.attachments : [];
        if (body.length === 0 && attachments.length === 0) {
            continue;
        }
        if (message.role === "assistant") {
            sections.push("## Assistant\n\n" + body);
            continue;
        }

        const userParts = ["## You"];
        if (body.length > 0) {
            userParts.push(quotedUserMarkdown(body));
        }
        if (attachments.length > 0) {
            const names = attachments.map(attachment => "- "
                + escapeMarkdownLiteral(normalizedAttachmentName(
                    attachment.displayName, "Attachment")));
            userParts.push("**Attachments**\n\n" + names.join("\n"));
        }
        sections.push(userParts.join("\n\n"));
    }
    return sections.join("\n\n") + "\n";
}

function sanitizedExportFilename(title, exportedAt) {
    const date = exportedAt instanceof Date ? exportedAt : new Date(exportedAt);
    const datePart = Number.isNaN(date.getTime())
        ? "export" : date.toISOString().slice(0, 10);
    let base = String(title || "conversation")
        .replace(/[\r\n\t]+/g, " ")
        .trim()
        .replace(/\s+/g, "-")
        .replace(/[^A-Za-z0-9._-]/g, "-")
        .replace(/-+/g, "-")
        .replace(/^[.-]+|[.-]+$/g, "")
        .slice(0, 64);
    if (base.length === 0) {
        base = "conversation";
    }
    return base + "-" + datePart + ".md";
}

function threadTitle(thread) {
    const persistedName = String((thread && thread.name) || "")
        .replace(/[\r\n\t]+/g, " ").trim();
    if (persistedName.length > 0) {
        return persistedName.slice(0, 120);
    }
    const rawPreview = String((thread && thread.preview) || "");
    const attachment = attachmentFromMetadataInput(rawPreview);
    if (attachment !== null) {
        return attachment.displayName;
    }
    if (isLegacyTextAttachmentInput(rawPreview)) {
        return "Text attachment";
    }
    const preview = rawPreview.replace(/[\r\n\t]+/g, " ").trim();
    if (preview.length > 80) {
        return preview.slice(0, 80) + "…";
    }
    return preview || "Untitled conversation";
}

function threadStatusText(status) {
    const type = typeof status === "string"
        ? status : String((status && status.type) || "notLoaded");
    if (type === "active") {
        return "Active";
    }
    if (type === "idle") {
        return "Ready";
    }
    if (type === "systemError") {
        return "Error";
    }
    return "Saved";
}

function historyUpdatedText(updatedAt, nowMilliseconds) {
    const timestamp = Number(updatedAt || 0) * 1000;
    const now = Number(nowMilliseconds || Date.now());
    if (!Number.isFinite(timestamp) || timestamp <= 0) {
        return "Unknown time";
    }
    const elapsed = Math.max(0, now - timestamp);
    if (elapsed < 60000) {
        return "Just now";
    }
    if (elapsed < 3600000) {
        return Math.floor(elapsed / 60000) + "m ago";
    }
    if (elapsed < 86400000) {
        return Math.floor(elapsed / 3600000) + "h ago";
    }
    if (elapsed < 604800000) {
        return Math.floor(elapsed / 86400000) + "d ago";
    }
    return new Date(timestamp).toISOString().slice(0, 10);
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
        return duration > 0
            ? "Waiting " + (duration / 1000).toFixed(1) + " seconds" : "";
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

function isActivityItem(item) {
    const type = String(item && item.type || "");
    return type.length > 0 && type !== "agentMessage"
        && type !== "userMessage" && type !== "functionCallOutput";
}

if (typeof module !== "undefined") {
    module.exports = {
        titleCase,
        conciseModelName,
        modelStatusText,
        modelById,
        modelsFromPayload,
        commandDraft,
        replaceCommandDraft,
        removeCommandDraft,
        commandItems,
        safeAssistantMarkdown,
        markdownBlocks,
        textFromBlocks,
        normalizedAttachmentName,
        attachmentMetadataInput,
        attachmentFromMetadataInput,
        messagesFromTurns,
        assistantResponseBody,
        isAssistantResponseTail,
        conversationMarkdown,
        sanitizedExportFilename,
        threadTitle,
        threadStatusText,
        historyUpdatedText,
        prettyValue,
        normalizedActivityStatus,
        activityStatusLabel,
        activityTitle,
        activityBody,
        activityOutput,
        isActivityItem
    };
}
