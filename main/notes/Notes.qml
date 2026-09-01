import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "NotesLogic.js" as NotesLogic

Scope {
    id: root

    property bool shown: false
    property string popupScreenName: ""
    property bool popupGrabFocus: false
    property int revision: 0
    property var pinnedIds: []
    property bool notesDirty: false
    property bool notesLoaded: false
    property bool destroying: false
    readonly property string persistedState: JSON.stringify(persistedNotes.notes)

    readonly property int noteCount: notesModel.count
    readonly property alias noteModel: notesModel
    readonly property int pinnedCount: pinnedIds.length
    readonly property var pinnedWindows: {
        root.pinnedIds;
        Quickshell.screens.length;

        const windows = [];
        for (let index = 0; index < root.pinnedIds.length; index++) {
            const noteId = root.pinnedIds[index];
            const noteIndex = root.noteIndex(noteId);
            if (noteIndex < 0) {
                continue;
            }

            const note = notesModel.get(noteIndex);
            const targetScreen = root.screenForName(note.screenName);
            if (targetScreen !== null) {
                windows.push({
                    noteId,
                    screen: targetScreen
                });
            }
        }

        return windows;
    }

    signal noteCreated(string noteId)

    onPersistedStateChanged: {
        if (!notesLoaded && persistedState !== "[]") {
            loadNotes();
        }
    }

    function newNoteId() {
        let noteId = "";
        do {
            noteId = `note-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;
        } while (noteIndex(noteId) >= 0);

        return noteId;
    }

    function noteIndex(noteId) {
        for (let index = 0; index < notesModel.count; index++) {
            if (notesModel.get(index).noteId === noteId) {
                return index;
            }
        }

        return -1;
    }

    function noteText(noteId) {
        const index = noteIndex(noteId);
        return index >= 0 ? notesModel.get(index).body : "";
    }

    function notePinned(noteId) {
        const index = noteIndex(noteId);
        return index >= 0 && notesModel.get(index).pinned;
    }

    function touchNotes() {
        revision++;
    }

    function scheduleSave() {
        notesDirty = true;
        saveTimer.restart();
    }

    function snapshotNotes() {
        const notes = [];
        for (let index = 0; index < notesModel.count; index++) {
            const note = notesModel.get(index);
            notes.push({
                noteId: note.noteId,
                body: note.body,
                pinned: note.pinned,
                screenName: note.screenName,
                createdAt: note.createdAt
            });
        }

        return notes;
    }

    function flushNotes() {
        if (!notesDirty) {
            return;
        }

        saveTimer.stop();
        persistedNotes.notes = snapshotNotes();
        notesFile.writeAdapter();
        notesDirty = false;
    }

    function refreshPinnedIds() {
        const ids = [];
        for (let index = 0; index < notesModel.count; index++) {
            const note = notesModel.get(index);
            if (note.pinned) {
                ids.push(note.noteId);
            }
        }
        pinnedIds = ids;
    }

    function loadNotes() {
        if (notesLoaded) {
            return;
        }
        notesLoaded = true;

        const normalizedNotes = NotesLogic.normalizeNotes(
            persistedNotes.notes,
            () => newNoteId()
        );

        for (let index = 0; index < normalizedNotes.length; index++) {
            notesModel.append(normalizedNotes[index]);
        }

        refreshPinnedIds();
        touchNotes();
    }

    function createNote() {
        notesLoaded = true;
        const noteId = newNoteId();
        notesModel.insert(0, {
            noteId,
            body: "",
            pinned: false,
            screenName: "",
            createdAt: Date.now()
        });
        if (!shown) {
            show();
        }
        touchNotes();
        scheduleSave();
        flushNotes();
        Qt.callLater(() => root.noteCreated(noteId));
    }

    function setNoteText(noteId, body) {
        const index = noteIndex(noteId);
        if (index < 0 || notesModel.get(index).body === body) {
            return;
        }

        notesModel.setProperty(index, "body", body);
        touchNotes();
        scheduleSave();
    }

    function pinNote(noteId, screenName) {
        const index = noteIndex(noteId);
        if (index < 0 || notesModel.get(index).pinned) {
            return;
        }

        notesModel.setProperty(index, "pinned", true);
        notesModel.setProperty(index, "screenName", screenName || "");
        refreshPinnedIds();
        touchNotes();
        scheduleSave();
        hide();
    }

    function unpinNote(noteId) {
        const index = noteIndex(noteId);
        if (index < 0 || !notesModel.get(index).pinned) {
            return;
        }

        notesModel.setProperty(index, "pinned", false);
        refreshPinnedIds();
        touchNotes();
        scheduleSave();
        flushNotes();
    }

    function deleteNote(noteId) {
        const index = noteIndex(noteId);
        if (index < 0) {
            return;
        }

        notesModel.remove(index);
        refreshPinnedIds();
        touchNotes();
        scheduleSave();
        flushNotes();
    }

    function screenForName(screenName) {
        for (let index = 0; index < Quickshell.screens.length; index++) {
            const candidate = Quickshell.screens[index];
            if (candidate.name === screenName) {
                return candidate;
            }
        }

        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function focusedScreenName() {
        for (let index = 0; index < Quickshell.screens.length; index++) {
            const candidate = Quickshell.screens[index];
            const monitor = Hyprland.monitorFor(candidate);
            if (monitor !== null && monitor.focused) {
                return candidate.name;
            }
        }

        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }

    function show(screenName, grabFocus) {
        popupScreenName = screenName || focusedScreenName();
        popupGrabFocus = grabFocus === true;
        shown = true;
    }

    function hide() {
        shown = false;
        flushNotes();
    }

    function toggle(screenName) {
        const requestedScreen = screenName || focusedScreenName();
        if (shown && (!screenName || popupScreenName === requestedScreen)) {
            hide();
        } else {
            show(requestedScreen, Boolean(screenName));
        }
    }

    Component.onCompleted: {
        if (persistedState !== "[]") {
            loadNotes();
        }
    }

    Component.onDestruction: {
        destroying = true;
        flushNotes();
    }

    ListModel {
        id: notesModel
    }

    FileView {
        id: notesFile

        path: Quickshell.stateDir + "/notes.json"
        blockLoading: true

        JsonAdapter {
            id: persistedNotes

            property var notes: []
        }
    }

    Timer {
        id: saveTimer

        interval: 250
        onTriggered: root.flushNotes()
    }

    IpcHandler {
        target: "notes"

        function toggle(): void {
            root.toggle();
        }

        function show(): void {
            root.show();
        }

        function hide(): void {
            root.hide();
        }

        function add(): void {
            root.createNote();
        }

    }

    Variants {
        model: root.pinnedWindows

        FloatingWindow {
            id: pinnedWindow

            required property var modelData

            screen: modelData.screen
            visible: true
            title: "Quickshell Note " + modelData.noteId
            color: "transparent"
            implicitWidth: 300
            implicitHeight: pinnedCard.implicitHeight
            minimumSize: Qt.size(300, pinnedCard.implicitHeight)
            maximumSize: Qt.size(300, pinnedCard.implicitHeight)

            onClosed: {
                if (!root.destroying && root.notePinned(modelData.noteId)) {
                    root.unpinNote(modelData.noteId);
                }
            }

            NoteCard {
                id: pinnedCard
                anchors.fill: parent
                controller: root
                noteId: pinnedWindow.modelData.noteId
                pinScreenName: pinnedWindow.screen.name
                dragEnabled: true

                onMoveRequested: pinnedWindow.startSystemMove()
            }
        }
    }
}
