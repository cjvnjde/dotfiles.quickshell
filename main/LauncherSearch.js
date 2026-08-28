const SOURCE_PENALTIES = {
    application: 0,
    command: 16,
    tool: 28
};

const FIELD_WEIGHTS = {
    name: 0,
    genericName: 22,
    keywords: 32,
    id: 36,
    command: 40,
    comment: 52,
    categories: 56
};

function normalize(value) {
    let text = String(value || "").toLowerCase().trim();
    if (text.normalize)
        text = text.normalize("NFKD").replace(/[\u0300-\u036f]/g, "");
    return text.replace(/[_-]+/g, " ").replace(/\s+/g, " ");
}

function isBoundary(text, index) {
    return index === 0 || /[\s/.:+@]/.test(text[index - 1]);
}

function wordPrefixIndex(text, pattern) {
    let index = text.indexOf(pattern);
    while (index !== -1) {
        if (isBoundary(text, index))
            return index;
        index = text.indexOf(pattern, index + 1);
    }
    return -1;
}

function fuzzyPenalty(text, pattern) {
    if (!pattern)
        return 0;
    if (!text)
        return Infinity;
    if (text === pattern)
        return 0;
    if (text.startsWith(pattern))
        return 8 + Math.min(4, (text.length - pattern.length) * 0.04);

    const wordIndex = wordPrefixIndex(text, pattern);
    if (wordIndex !== -1)
        return 18 + wordIndex * 0.15;

    const substringIndex = text.indexOf(pattern);
    if (substringIndex !== -1)
        return 30 + substringIndex * 0.2;

    let patternIndex = 0;
    let firstMatch = -1;
    let previousMatch = -1;
    let gaps = 0;
    let consecutive = 0;
    let boundaries = 0;

    for (let index = 0; index < text.length && patternIndex < pattern.length; index++) {
        if (text[index] !== pattern[patternIndex])
            continue;

        if (firstMatch === -1)
            firstMatch = index;
        if (isBoundary(text, index))
            boundaries++;
        if (previousMatch !== -1) {
            const gap = index - previousMatch - 1;
            gaps += gap;
            if (gap === 0)
                consecutive++;
        }

        previousMatch = index;
        patternIndex++;
    }

    if (patternIndex !== pattern.length)
        return Infinity;

    return Math.max(38,
        48
        + firstMatch * 1.2
        + gaps * 1.7
        + (text.length - pattern.length) * 0.03
        - consecutive * 2.8
        - boundaries * 4.5);
}

function scoreFields(fields, query) {
    const normalizedQuery = normalize(query);
    if (!normalizedQuery)
        return 0;

    const normalizedFields = [];
    for (let index = 0; index < fields.length; index++) {
        const field = fields[index];
        const text = normalize(field.text);
        if (text)
            normalizedFields.push({
                text: text,
                weight: field.weight || 0,
                fuzzy: field.fuzzy !== false
            });
    }

    let phraseScore = Infinity;
    for (let index = 0; index < normalizedFields.length; index++) {
        const field = normalizedFields[index];
        if (field.fuzzy || field.text.indexOf(normalizedQuery) !== -1) {
            phraseScore = Math.min(phraseScore,
                fuzzyPenalty(field.text, normalizedQuery) + field.weight);
        }
    }

    const tokens = normalizedQuery.split(" ").filter(token => token.length > 0);
    let tokenScore = 0;
    for (let tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
        let bestTokenScore = Infinity;
        for (let fieldIndex = 0; fieldIndex < normalizedFields.length; fieldIndex++) {
            const field = normalizedFields[fieldIndex];
            if (field.fuzzy || field.text.indexOf(tokens[tokenIndex]) !== -1) {
                bestTokenScore = Math.min(bestTokenScore,
                    fuzzyPenalty(field.text, tokens[tokenIndex]) + field.weight);
            }
        }
        if (!Number.isFinite(bestTokenScore))
            return phraseScore;
        tokenScore += bestTokenScore;
    }

    if (tokens.length > 1)
        tokenScore = tokenScore / tokens.length + 6;
    return Math.min(phraseScore, tokenScore);
}

function usageBoost(record, now) {
    if (!record)
        return 0;

    const count = Math.max(0, Number(record.count) || 0);
    const lastUsed = Math.max(0, Number(record.lastUsed) || 0);
    const countBoost = Math.min(6, Math.log2(count + 1) * 1.8);
    const age = Math.max(0, (now || Date.now()) - lastUsed);
    const week = 7 * 24 * 60 * 60 * 1000;
    const recencyBoost = lastUsed > 0 ? 4 * Math.exp(-age / week) : 0;
    return countBoost + recencyBoost;
}

function scoreResult(fields, query, kind, record, now) {
    const matchScore = scoreFields(fields, query);
    if (!Number.isFinite(matchScore))
        return Infinity;
    return matchScore + (SOURCE_PENALTIES[kind] || 0) - usageBoost(record, now);
}

function applicationKind(runInTerminal, categories) {
    if (runInTerminal)
        return "command";

    const normalizedCategories = normalize((categories || []).join(" "));
    const isAppLike = /(^| )(terminalemulator|filemanager)( |$)/.test(normalizedCategories);
    const isTool = /(^| )(settings|system)( |$)/.test(normalizedCategories);
    return isTool && !isAppLike ? "tool" : "application";
}

function field(name, text) {
    return {
        text: text,
        weight: FIELD_WEIGHTS[name] || 0,
        fuzzy: name === "name" || name === "genericName"
    };
}

function compareResults(left, right) {
    if (left.score !== right.score)
        return left.score - right.score;
    if (left.kind !== right.kind)
        return (SOURCE_PENALTIES[left.kind] || 0) - (SOURCE_PENALTIES[right.kind] || 0);
    return left.name.localeCompare(right.name);
}

function commandName(command) {
    if (!command || command.length === 0)
        return "";
    const parts = String(command[0]).split("/");
    return parts[parts.length - 1];
}

function kindLabel(kind) {
    if (kind === "application")
        return "Application";
    if (kind === "command")
        return "Command";
    return "Tool";
}

function buildResults(applications, commands, tools, value, usageEntries, now, limit) {
    const query = String(value || "").trim();
    const history = usageEntries || {};
    const representedCommands = {};
    const matches = [];

    for (const application of applications || []) {
        const categories = application.categories || [];
        const keywords = application.keywords || [];
        const command = application.command || [];
        const executable = commandName(command);
        const kind = applicationKind(application.runInTerminal, categories);
        const key = "application:" + application.id;
        const score = scoreResult([
            field("name", application.name),
            field("genericName", application.genericName),
            field("keywords", keywords.join(" ")),
            field("id", application.id),
            field("command", command.join(" ")),
            field("comment", application.comment),
            field("categories", categories.join(" "))
        ], query, kind, history[key], now);

        if (executable)
            representedCommands[executable] = true;
        if (!Number.isFinite(score))
            continue;

        matches.push({
            key: key,
            kind: kind,
            kindLabel: kindLabel(kind),
            name: application.name,
            subtitle: application.genericName || application.comment || application.id,
            icon: application.icon,
            application: application,
            command: executable,
            score: score
        });
    }

    if (query) {
        const invocation = query.match(/^(\S+)\s+(.+)$/);
        const invokedCommand = invocation ? invocation[1] : "";

        for (const command of commands || []) {
            const isInvocation = command === invokedCommand;
            if (representedCommands[command] && !isInvocation)
                continue;

            const key = "command:" + command;
            const score = scoreResult([
                field("name", command)
            ], isInvocation ? invokedCommand : query, "command", history[key], now);
            if (!Number.isFinite(score))
                continue;

            matches.push({
                key: key,
                kind: "command",
                kindLabel: "Command",
                name: isInvocation ? query : command,
                subtitle: isInvocation ? "Run in Ghostty" : "Available in PATH",
                icon: "utilities-terminal",
                application: null,
                command: command,
                commandLine: isInvocation ? query : "",
                score: score
            });
        }
    }

    for (const tool of tools || []) {
        const score = scoreResult([
            field("name", tool.name),
            field("keywords", tool.keywords),
            field("comment", tool.subtitle)
        ], query, "tool", history[tool.key], now);
        if (!Number.isFinite(score))
            continue;

        matches.push({
            key: tool.key,
            kind: "tool",
            kindLabel: "Tool",
            name: tool.name,
            subtitle: tool.subtitle,
            icon: tool.icon,
            application: null,
            command: "",
            toolAction: tool.action,
            score: score
        });
    }

    matches.sort(compareResults);
    return matches.slice(0, limit || 200);
}

if (typeof module !== "undefined") {
    module.exports = {
        normalize,
        fuzzyPenalty,
        scoreFields,
        usageBoost,
        scoreResult,
        applicationKind,
        field,
        compareResults,
        buildResults,
        FIELD_WEIGHTS,
        SOURCE_PENALTIES
    };
}
