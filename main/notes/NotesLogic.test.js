const assert = require("node:assert/strict");
const test = require("node:test");

const logic = require("./NotesLogic.js");

test("normalizeNotes restores safe persisted note records", () => {
    let generatedId = 0;
    const notes = logic.normalizeNotes([
        {
            noteId: "kept",
            body: "Remember this",
            pinned: true,
            screenName: "DP-1",
            createdAt: 42
        },
        {
            noteId: "kept",
            body: 12,
            pinned: "yes"
        }
    ], () => `generated-${++generatedId}`);

    assert.deepEqual(notes[0], {
        noteId: "kept",
        body: "Remember this",
        pinned: true,
        screenName: "DP-1",
        createdAt: 42
    });
    assert.equal(notes[1].noteId, "generated-1");
    assert.equal(notes[1].body, "");
    assert.equal(notes[1].pinned, false);
});

test("normalizeNotes accepts QML array-like values", () => {
    const notes = logic.normalizeNotes({
        0: {
            noteId: "qml-note",
            body: "Loaded from JsonAdapter"
        },
        length: 1
    });

    assert.equal(notes.length, 1);
    assert.equal(notes[0].noteId, "qml-note");
    assert.equal(notes[0].body, "Loaded from JsonAdapter");
});

test("normalizeNotes rejects a non-array state payload", () => {
    assert.deepEqual(logic.normalizeNotes({ notes: [] }), []);
});

