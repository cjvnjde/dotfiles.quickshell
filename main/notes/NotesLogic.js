function normalizedTimestamp(value, fallback) {
    const timestamp = Number(value);
    return Number.isFinite(timestamp) ? Math.max(0, timestamp) : fallback;
}

function normalizeNotes(value, createId) {
    if (value === null || typeof value !== "object"
            || typeof value.length !== "number") {
        return [];
    }

    const seenIds = Object.create(null);
    const normalizedNotes = [];

    for (let index = 0; index < value.length; index++) {
        const note = value[index];
        const source = note && typeof note === "object" ? note : {};
        let noteId = String(source.noteId || "").trim();
        let generationAttempt = 0;

        while (noteId.length === 0 || seenIds[noteId]) {
            noteId = createId
                ? String(createId()).trim()
                : `restored-note-${index}-${generationAttempt}`;
            generationAttempt++;
        }
        seenIds[noteId] = true;

        normalizedNotes.push({
            noteId,
            body: typeof source.body === "string" ? source.body : "",
            pinned: source.pinned === true,
            screenName: typeof source.screenName === "string"
                ? source.screenName : "",
            createdAt: normalizedTimestamp(source.createdAt, Date.now())
        });
    }

    return normalizedNotes;
}

if (typeof module !== "undefined") {
    module.exports = {
        normalizeNotes
    };
}
