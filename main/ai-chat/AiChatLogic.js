const COMMAND_CATALOG = [
    {
        label: "/file",
        detail: "Attach an image or text file",
        draft: "/file",
        immediate: true
    },
    {
        label: "/screenshot",
        detail: "Capture a screen region",
        draft: "/screenshot",
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
        label: "/pin",
        detail: "Keep chat open as a managed window",
        draft: "/pin",
        immediate: true
    },
    {
        label: "/unpin",
        detail: "Return chat to popup mode",
        draft: "/unpin",
        immediate: true
    },
    {
        label: "/theme",
        detail: "Choose a theme and light or dark mode",
        draft: "/theme ",
        immediate: false
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
        label: "/preset",
        detail: "Apply a model and thinking preset",
        draft: "/preset ",
        immediate: false
    },
    {
        label: "/project",
        detail: "Switch AI project",
        draft: "/project ",
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

function modelStatusText(modelName, effortName, presetName) {
    const effort = effortName === "" || effortName === "default"
        ? "Auto" : titleCase(effortName);
    const preset = String(presetName || "").trim();
    return conciseModelName(modelName) + " " + effort
        + (preset.length > 0 ? " · " + preset : "");
}

function presetByName(presets, name) {
    const requested = String(name || "").trim().toLowerCase();
    const configured = Array.isArray(presets) ? presets : [];
    for (const preset of configured) {
        if (!preset) {
            continue;
        }
        const presetName = String(preset.name || "").trim();
        if (presetName.length > 0 && presetName.toLowerCase() === requested) {
            return preset;
        }
    }
    return null;
}

function projectById(projects, projectId) {
    const requested = String(projectId || "").trim().toLowerCase();
    const configured = Array.isArray(projects) ? projects : [];
    for (const project of configured) {
        if (project && String(project.id || "").toLowerCase() === requested) {
            return project;
        }
    }
    return null;
}

function matchingPresetName(presets, modelId, effortName) {
    const activeModel = String(modelId || "").trim().toLowerCase();
    const activeEffort = String(effortName || "default").trim().toLowerCase();
    const configured = Array.isArray(presets) ? presets : [];
    for (const preset of configured) {
        if (!preset) {
            continue;
        }
        const name = String(preset.name || "").trim();
        const model = String(preset.model || "").trim().toLowerCase();
        const thinking = String(preset.thinking || "").trim().toLowerCase();
        if (name.length > 0 && model === activeModel
                && thinking === activeEffort) {
            return name;
        }
    }
    return "";
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
        supportedEfforts, selectedEffort, presets, pinned, projects,
        activeProjectId) {
    const value = String(draft || "").replace(/^\s+/, "");
    const lowered = value.toLowerCase();
    if (lowered.indexOf("/project") === 0
            && (lowered.length === 8 || lowered.charAt(8) === " ")) {
        const query = lowered.slice(8).trim();
        const configured = Array.isArray(projects) ? projects : [];
        return configured.filter(project => {
            if (!project) {
                return false;
            }
            const id = String(project.id || "");
            const label = String(project.label || id);
            const description = String(project.description || "");
            return id.length > 0 && (query.length === 0
                || id.toLowerCase().indexOf(query) >= 0
                || label.toLowerCase().indexOf(query) >= 0
                || description.toLowerCase().indexOf(query) >= 0);
        }).map(project => {
            const id = String(project.id);
            const label = String(project.label || id);
            const description = String(project.description || "");
            return {
                label,
                detail: id === activeProjectId
                    ? "Current project"
                    : description.length > 0 ? description : id,
                draft: "/project " + id,
                immediate: true
            };
        });
    }

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
    if (lowered.indexOf("/preset") === 0
            && (lowered.length === 7 || lowered.charAt(7) === " ")) {
        const query = lowered.slice(7).trim();
        const activePreset = matchingPresetName(
            presets, selectedModel, selectedEffort);
        const configured = Array.isArray(presets) ? presets : [];
        return configured.filter(preset => {
            if (!preset) {
                return false;
            }
            const name = String(preset.name || "").trim();
            const model = String(preset.model || "").trim();
            const thinking = String(preset.thinking || "").trim();
            return name.length > 0 && model.length > 0 && thinking.length > 0
                && (query.length === 0
                    || name.toLowerCase().indexOf(query) >= 0);
        }).map(preset => {
            const name = String(preset.name).trim();
            const model = String(preset.model).trim();
            const thinking = String(preset.thinking).trim().toLowerCase();
            const summary = conciseModelName(model) + " "
                + (thinking === "default" ? "Auto" : titleCase(thinking));
            return {
                label: name,
                detail: name === activePreset
                    ? "Current preset — " + summary : summary,
                draft: "/preset " + name,
                immediate: true
            };
        });
    }


    return COMMAND_CATALOG.filter(command => {
        if (command.label === "/pin" && pinned === true) {
            return false;
        }
        if (command.label === "/unpin" && pinned !== true) {
            return false;
        }
        return command.label.indexOf(lowered) === 0;
    });
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
        activityTitle: "",
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
        let assistant = null;
        let assistantIndex = -1;
        let activeActivity = null;

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
                const part = String(item.text || "");
                if (assistant === null) {
                    assistant = persistedMessage(
                        "assistant",
                        part,
                        turnStatus,
                        threadId,
                        turnId,
                        itemId,
                        [],
                        createdAt,
                        ordinal++
                    );
                    messages.push(assistant);
                    assistantIndex = messages.length - 1;
                } else {
                    if (part.length > 0) {
                        assistant.body += (assistant.body.length > 0 ? "\n\n" : "")
                            + part;
                    }
                    if (itemId.length > 0) {
                        assistant.itemId = itemId;
                    }
                }
                activeActivity = null;
                continue;
            }
            if (isActivityItem(item)
                    && normalizedActivityStatus(item.status, "completed")
                        === "streaming") {
                activeActivity = item;
            }
        }

        if (assistant === null
                && (turnStatus === "streaming" || turnStatus === "failed"
                    || turnStatus === "interrupted")) {
            assistant = persistedMessage(
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
            messages.push(assistant);
            assistantIndex = messages.length - 1;
        }
        if (assistant !== null && turnStatus === "streaming") {
            assistant.activityTitle = activeActivity === null
                ? "thinking…" : loadingActivityText(activeActivity);
        }

        const failure = turn.error || {};
        const failureMessage =
            turnStatus === "failed"
                ? String(failure.message || "The Codex turn failed.").slice(0, 600)
                : "";
        if (failureMessage.length > 0 && assistantIndex >= 0) {
            messages[assistantIndex].errorText = failureMessage;
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


function normalizedActivityStatus(value, fallback) {
    const status = String(value || fallback || "streaming");
    return status === "inProgress" ? "streaming" : status;
}


function loadingActivityText(item) {
    const type = String(item && item.type || "");
    if (type === "turn" || type === "reasoning") {
        return "thinking…";
    }
    if (type === "plan") {
        return "planning…";
    }
    if (type === "commandExecution") {
        return "running command…";
    }
    if (type === "fileChange") {
        return "editing files…";
    }
    if (type === "webSearch") {
        return "searching web…";
    }
    if (type === "imageGeneration") {
        return "generating image…";
    }
    if (type === "imageView") {
        return "viewing image…";
    }
    if (type === "sleep") {
        return "waiting…";
    }
    if (type === "contextCompaction") {
        return "compacting conversation…";
    }
    if (type === "enteredReviewMode" || type === "exitedReviewMode") {
        return "reviewing…";
    }
    if (type === "mcpToolCall" || type === "dynamicToolCall") {
        return "using tool…";
    }
    if (type === "collabToolCall") {
        return "working with agent…";
    }
    return "working…";
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
        presetByName,
        projectById,
        matchingPresetName,
        modelById,
        modelsFromPayload,
        commandDraft,
        replaceCommandDraft,
        removeCommandDraft,
        commandItems,
        safeAssistantMarkdown,
        markdownBlocks,
        loadingActivityText,
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
        isActivityItem
    };
}
