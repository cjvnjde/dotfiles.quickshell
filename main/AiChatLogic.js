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
        label: "/new",
        detail: "Start a new chat",
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
        detail: "Recreate the sandbox and update Codex",
        draft: "/rebuild",
        immediate: true
    }
];

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
        supportedEfforts, selectedEffort) {
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
        prettyValue,
        normalizedActivityStatus,
        activityStatusLabel,
        activityTitle,
        activityBody,
        activityOutput,
        isActivityItem
    };
}
