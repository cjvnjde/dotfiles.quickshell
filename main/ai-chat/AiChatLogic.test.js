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
            "/preset", [], "gpt-5.4", ["low"], "low", presets
        ).map(item => item.label),
        ["fast", "deep"]
    );
    assert.deepEqual(
        logic.commandItems(
            "/preset f", [], "gpt-5.4", ["low"], "low", presets
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
        "/", [], "", [], "", [], false
    ).map(item => item.label);

    assert.ok(labels.includes("/screenshot"));
    assert.ok(!labels.includes("/ps"));
    assert.ok(!labels.includes("/activity"));
});

test("window mode commands expose only the available transition", () => {
    function modeCommands(pinned) {
        return logic.commandItems(
            "/", [], "", [], "", [], pinned
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

test("Markdown previews retain text, code and image response order", () => {
    assert.deepEqual(logic.markdownBlocks(
        'Before ![Chart](<sandbox:/home/agent/quickshell-ai-outputs/plot (1).png> "Plot") after.\n'
        + "```text\n![not an image](secret.png)\n```\n"
        + '[Download](plots/chart(2).PNG?raw=1#preview) [Docs](guide.pdf)'
    ), [
        { kind: "markdown", language: "", text: "Before " },
        {
            kind: "image",
            language: "sandbox:/home/agent/quickshell-ai-outputs/plot (1).png",
            text: "Chart"
        },
        { kind: "markdown", language: "", text: " after." },
        { kind: "code", language: "text", text: "![not an image](secret.png)" },
        { kind: "image", language: "plots/chart(2).PNG?raw=1#preview", text: "Download" },
        { kind: "markdown", language: "", text: " [Docs](guide.pdf)" }
    ]);
});

test("reference previews resolve forward, collapsed and shortcut labels without losing normal links", () => {
    const blocks = logic.markdownBlocks(
        "![First][ My Chart ] ![SECOND][] ![third] [Manual][docs]\n\n"
        + '[my chart]: <plots/first chart.png> "Title"\n'
        + "[second]: second.jpg\n"
        + "[third]: third.webp\n"
        + "[docs]: https://example.com/manual\n"
        + "[MY CHART]: ignored.png"
    );
    assert.deepEqual(blocks.filter(block => block.kind === "image"), [
        { kind: "image", language: "plots/first chart.png", text: "First" },
        { kind: "image", language: "second.jpg", text: "SECOND" },
        { kind: "image", language: "third.webp", text: "third" }
    ]);
    const prose = blocks.filter(block => block.kind === "markdown")
        .map(block => block.text).join("\n");
    assert.match(prose, /\[Manual\]\[docs\]/);
    assert.match(prose, /\[docs\]: https:\/\/example\.com\/manual/);
    assert.doesNotMatch(prose, /ignored\.png/);
});

test("escaped and code image syntax never becomes a preview", () => {
    const text = "\\![escaped](private.png) \\[escaped link](private.jpg) "
        + "`![inline](private.png)` ``![ticks ` inside](private.png)``\n"
        + "~~~~\n![fenced](private.png)\n~~~\n";
    const blocks = logic.markdownBlocks(text);
    assert.deepEqual(blocks.map(block => block.kind), ["markdown", "code"]);
    assert.match(blocks[0].text, /private\.png/);
    assert.equal(blocks[1].text, "![fenced](private.png)\n~~~\n");
    assert.deepEqual(
        logic.markdownBlocks("\\\\![visible](public.png)").filter(block => block.kind === "image"),
        [{ kind: "image", language: "public.png", text: "visible" }]
    );
});

test("incomplete images remain safe text until their destination closes", () => {
    const partial = 'Text ![plot](charts/plot(1).png "title"';
    assert.deepEqual(logic.markdownBlocks(partial), [
        { kind: "markdown", language: "", text: partial }
    ]);
    assert.deepEqual(logic.markdownBlocks(partial + ")"), [
        { kind: "markdown", language: "", text: "Text " },
        { kind: "image", language: "charts/plot(1).png", text: "plot" }
    ]);
    assert.equal(
        logic.safeAssistantMarkdown('<img src="file:///secret"> ![missing][unknown] \\\\![even](x) \\![odd](x)'),
        '&lt;img src="file:///secret"> \\![missing][unknown] \\\\\\![even](x) \\![odd](x)'
    );
});

test("data destinations and escaped balanced destinations retain exact image bytes", () => {
    const data = "data:image/png;base64,iVBORw0KGgoAAA+/==";
    assert.deepEqual(logic.markdownBlocks(
        "![generated](" + data + ") ![a\\]b](plot\\(one\\).png)"
    ).filter(block => block.kind === "image"), [
        { kind: "image", language: data, text: "generated" },
        { kind: "image", language: "plot(one).png", text: "a]b" }
    ]);
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
                { id: "answer-one", type: "agentMessage", text: "First" },
                { id: "command", type: "commandExecution", status: "completed" },
                { id: "answer-two", type: "agentMessage", text: "Done" }
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
        ["user", "assistant", "assistant", "assistant"]
    );
    assert.equal(messages[0].body, "multiline\nrequest");
    assert.deepEqual(
        messages[0].attachments.map((attachment) => attachment.displayName),
        ["chart.png", "notes.txt"]
    );
    assert.ok(messages[0].attachments.every((attachment) => attachment.hostPath === ""));
    assert.equal(messages[1].body, "First\n\nDone");
    assert.equal(messages[2].messageStatus, "failed");
    assert.equal(messages[2].errorText, "Backend failed");
    assert.equal(messages[3].messageStatus, "interrupted");
    assert.doesNotMatch(JSON.stringify(messages), /private\.(png|txt)/);
});

test("generated images survive history reconstruction between response text", () => {
    const image = {
        id: "image", type: "imageGeneration", status: "completed",
        result: "iVBORw0KGgo=", savedPath: "/private/generated.png"
    };
    const messages = logic.messagesFromTurns([{
        id: "turn", status: "completed", items: [
            { id: "before", type: "agentMessage", text: "Before" },
            image,
            { id: "failed", type: "imageGeneration", status: "failed", result: "" },
            { id: "after", type: "agentMessage", text: "After" }
        ]
    }], "thread");
    assert.equal(messages.length, 1);
    const blocks = logic.markdownBlocks(messages[0].body);
    assert.deepEqual(blocks.map(block => block.kind), ["markdown", "image", "markdown"]);
    assert.equal(blocks[0].text.trim(), "Before");
    assert.equal(blocks[1].language, "data:image/png;base64,iVBORw0KGgo=");
    assert.equal(blocks[2].text.trim(), "After");
    assert.doesNotMatch(messages[0].body, /private/);
    const liveImage = logic.markdownBlocks(logic.assistantItemMarkdown(image));
    assert.deepEqual(liveImage, [blocks[1]]);
});

test("saved generated images retain encoded paths without injecting Markdown", () => {
    const body = logic.assistantItemMarkdown({
        type: "imageGeneration", status: "completed", result: "",
        savedPath: "/home/agent/quickshell-ai-outputs/a [plot](1)#.png"
    });
    const blocks = logic.markdownBlocks(body);
    assert.equal(blocks.length, 1);
    assert.equal(blocks[0].kind, "image");
    assert.equal(decodeURIComponent(blocks[0].language),
        "/home/agent/quickshell-ai-outputs/a [plot](1)#.png");
    assert.equal(logic.assistantItemMarkdown({
        type: "imageGeneration", status: "in_progress", result: ""
    }), null);
});

test("messagesFromTurns represents an in-progress turn without eager duplication", () => {
    const turns = [{ id: "active", status: "inProgress", items: [] }];
    const first = logic.messagesFromTurns(turns, "thread");
    const second = logic.messagesFromTurns(turns, "thread");

    assert.deepEqual(first, second);
    assert.equal(first.length, 1);
    assert.equal(first[0].role, "assistant");
    assert.equal(first[0].messageStatus, "streaming");
    assert.equal(first[0].activityTitle, "thinking…");
});

test("activity labels stay terse while work is in progress", () => {
    assert.equal(
        logic.loadingActivityText({ type: "reasoning" }),
        "thinking…"
    );
    assert.equal(
        logic.loadingActivityText({ type: "commandExecution" }),
        "running command…"
    );
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

test("project command lists, filters, and marks configured projects", () => {
    const projects = [
        { id: "general", label: "General", description: "General AI chat" },
        { id: "english", label: "English", description: "Language coach" },
        { id: "jira", label: "Jira", description: "Issue management" }
    ];

    assert.deepEqual(
        logic.commandItems(
            "/project", [], "", [], "", [], false, projects, "english"
        ),
        [
            {
                label: "General",
                detail: "General AI chat",
                draft: "/project general",
                immediate: true
            },
            {
                label: "English",
                detail: "Current project",
                draft: "/project english",
                immediate: true
            },
            {
                label: "Jira",
                detail: "Issue management",
                draft: "/project jira",
                immediate: true
            }
        ]
    );
    assert.deepEqual(
        logic.commandItems(
            "/project lang", [], "", [], "", [], false, projects, "general"
        ).map(item => item.draft),
        ["/project english"]
    );
    assert.equal(logic.projectById(projects, "JIRA"), projects[2]);
    assert.equal(logic.projectById(projects, "missing"), null);
});
