const assert = require("node:assert/strict");
const test = require("node:test");

const logic = require("./AiChatLogic.js");

test("preset commands resolve configured names", () => {
    const presets = [
        { name: "fast", model: "gpt-5.4", thinking: "low" },
        { name: "deep", model: "gpt-5.4", thinking: "high" }
    ];

    assert.equal(logic.presetByName(presets, "FAST"), presets[0]);
    assert.deepEqual(
        logic.commandItems(
            "/preset", [], "gpt-5.4", ["low"], "low", "detailed", presets
        ).map(item => item.label),
        ["fast", "deep"]
    );
    assert.deepEqual(
        logic.commandItems(
            "/preset f", [], "gpt-5.4", ["low"], "low", "detailed", presets
        ),
        [{
            label: "fast",
            detail: "Current preset — 5.4 Low",
            draft: "/preset fast",
            immediate: true
        }]
    );
});

test("screenshot command uses a descriptive name", () => {
    const labels = logic.commandItems(
        "/", [], "", [], "", "detailed", [], false
    ).map(item => item.label);

    assert.ok(labels.includes("/screenshot"));
    assert.ok(!labels.includes("/ps"));
});

test("window mode commands expose only the available transition", () => {
    function modeCommands(pinned) {
        return logic.commandItems(
            "/", [], "", [], "", "detailed", [], pinned
        ).map(item => item.label)
            .filter(label => label === "/pin" || label === "/unpin");
    }

    assert.deepEqual(modeCommands(false), ["/pin"]);
    assert.deepEqual(modeCommands(true), ["/unpin"]);
});

test("preset status requires both model and thinking to match", () => {
    const presets = [
        { name: "fast", model: "gpt-5.4", thinking: "low" }
    ];

    const matching = logic.matchingPresetName(
        presets, "gpt-5.4", "low"
    );
    assert.equal(matching, "fast");
    assert.equal(
        logic.modelStatusText("GPT-5.4", "low", matching),
        "5.4 Low · fast"
    );
    assert.equal(
        logic.matchingPresetName(presets, "gpt-5.4", "medium"),
        ""
    );
    assert.equal(
        logic.matchingPresetName(presets, "gpt-5.3", "low"),
        ""
    );
});

test("conversationMarkdown preserves assistant Markdown and safely quotes user content", () => {
    const assistant = '## Result\n\n```js\nconsole.log("ok");\n```';
    const markdown = logic.conversationMarkdown("Demo #1", "2026-08-30T12:34:56.000Z", [
        {
            role: "user",
            body: "first line\n# not a heading <private> &copy;",
            attachments: [{ displayName: "notes [draft].txt" }]
        },
        { role: "activity", body: "/home/private", attachments: [] },
        { role: "assistant", body: assistant, attachments: [] },
        { role: "notice", body: "transient", attachments: [] }
    ]);

    assert.ok(markdown.startsWith("# Demo \\#1\n\n_Exported: 2026\\-08\\-30T12:34:56\\.000Z_"));
    assert.ok(markdown.includes("> first line\n> \\# not a heading &lt;private\\> &amp;copy;"));
    assert.ok(markdown.includes("- notes \\[draft\\]\\.txt"));
    assert.ok(markdown.includes("## Assistant\n\n" + assistant));
    assert.doesNotMatch(markdown, /transient|\/home\/private/);
});

test("markdownBlocks exposes incomplete fenced code while a response streams", () => {
    assert.deepEqual(
        logic.markdownBlocks("Intro **now**.\n\n```js\nconst answer = 42;"),
        [
            {
                kind: "markdown",
                language: "",
                text: "Intro **now**.\n"
            },
            {
                kind: "code",
                language: "js",
                text: "const answer = 42;"
            }
        ]
    );
    assert.deepEqual(
        logic.markdownBlocks(
            "Intro **now**.\n\n```js\nconst answer = 42;\n```\nDone."
        ),
        [
            {
                kind: "markdown",
                language: "",
                text: "Intro **now**.\n"
            },
            {
                kind: "code",
                language: "js",
                text: "const answer = 42;"
            },
            {
                kind: "markdown",
                language: "",
                text: "Done."
            }
        ]
    );
});

test("messagesFromTurns hydrates attachments and terminal turn states", () => {
    const imageMetadata = logic.attachmentMetadataInput(
        "image",
        "chart.png",
        "/tmp/quickshell-ai/private.png"
    );
    const textMetadata = logic.attachmentMetadataInput(
        "text",
        "notes.txt",
        "/tmp/quickshell-ai/private.txt"
    );
    const turns = [
        {
            id: "turn-complete",
            status: "completed",
            startedAt: 1_700_000_000,
            items: [
                {
                    id: "user-one",
                    type: "userMessage",
                    content: [
                        { type: "text", text: "multiline\nrequest" },
                        { type: "text", text: imageMetadata },
                        { type: "localImage", path: "/tmp/quickshell-ai/private.png" },
                        { type: "text", text: textMetadata }
                    ]
                },
                { id: "reasoning", type: "reasoning", summary: ["Checked"] },
                { id: "answer", type: "agentMessage", text: "Done" }
            ]
        },
        {
            id: "turn-failed",
            status: "failed",
            error: { message: "Backend failed" },
            items: [{ id: "user-two", type: "userMessage", content: [] }]
        },
        {
            id: "turn-interrupted",
            status: "interrupted",
            items: []
        }
    ];

    const messages = logic.messagesFromTurns(turns, "thread-one");
    assert.deepEqual(
        messages.map((message) => message.role),
        ["user", "activity", "assistant", "assistant", "assistant"]
    );
    assert.equal(messages[0].body, "multiline\nrequest");
    assert.deepEqual(
        messages[0].attachments.map((attachment) => attachment.displayName),
        ["chart.png", "notes.txt"]
    );
    assert.ok(messages[0].attachments.every((attachment) => attachment.hostPath === ""));
    assert.equal(messages[3].messageStatus, "failed");
    assert.equal(messages[3].errorText, "Backend failed");
    assert.equal(messages[4].messageStatus, "interrupted");
    assert.doesNotMatch(JSON.stringify(messages), /private\.(png|txt)/);
});

test("messagesFromTurns represents an in-progress turn without eager duplication", () => {
    const turns = [{ id: "active", status: "inProgress", items: [] }];
    const first = logic.messagesFromTurns(turns, "thread");
    const second = logic.messagesFromTurns(turns, "thread");

    assert.deepEqual(first, second);
    assert.equal(first.length, 1);
    assert.equal(first[0].role, "activity");
    assert.equal(first[0].messageStatus, "streaming");
    assert.equal(first[0].itemId, "turn:active");
});

test("assistant responses expose one tail action and copy every answer part", () => {
    const messages = [
        { role: "assistant", turnId: "turn-a", body: "First part" },
        { role: "activity", turnId: "turn-a", body: "Thinking" },
        { role: "assistant", turnId: "turn-a", body: "Second part" },
        { role: "assistant", turnId: "turn-b", body: "Another response" }
    ];

    assert.equal(
        logic.assistantResponseBody(messages, 0),
        "First part\n\nSecond part"
    );
    assert.equal(
        logic.assistantResponseBody(messages, 2),
        "First part\n\nSecond part"
    );
    assert.equal(logic.isAssistantResponseTail(messages, 0), false);
    assert.equal(logic.isAssistantResponseTail(messages, 2), true);
    assert.equal(logic.isAssistantResponseTail(messages, 3), true);
});

test("sanitizedExportFilename retains the Markdown extension", () => {
    assert.equal(
        logic.sanitizedExportFilename("../Quarter: report?", "2026-08-30T00:00:00Z"),
        "Quarter-report-2026-08-30.md"
    );
});

test("threadTitle hides internal attachment metadata and paths", () => {
    const preview = logic.attachmentMetadataInput(
        "text",
        "notes]]draft.txt",
        "/tmp/quickshell-ai/private.txt"
    );

    assert.equal(logic.threadTitle({ preview }), "notes]]draft.txt");
    assert.doesNotMatch(logic.threadTitle({ preview }), /quickshell-ai|private/);
});
