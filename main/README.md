# Quickshell Catppuccin shell

A compositor-neutral Quickshell setup with a Catppuccin Mocha top bar and a
freedesktop notification daemon.

## Run

From this directory:

```sh
qs -p .
```

To use it as the default config, run `qs` normally while this directory is
located at `~/.config/quickshell/main`.

The bar reserves 24 pixels at the top of every display. Notifications appear in
the upper-right corner with an even six-pixel gap from the bar and screen edge.
They support application actions, and critical notifications remain visible until dismissed.

## Structure

- `topbar/` contains the bar and its controls.
- `notifications/` contains the notification daemon and cards.
- `ai-chat/` contains the AI chat UI, controller, helpers, tests, and chat kit.
- `notes/` contains persistent note cards and pinned note windows.
- `AppLauncher.qml` and `Theme.qml` remain shared at the configuration root.

## Launcher

Press `Super+T` to open the centered launcher. It fuzzy-searches desktop
applications, commands available in `PATH`, and built-in tools. Application
names are preferred over commands, followed by system tools; exact matches,
word boundaries, recent use, and launch frequency refine that order. Selecting
a command opens it in Ghostty. A full invocation such as `git status` can be
entered directly.

Use `Up`/`Down` to select a result and `Enter` to launch it. Mathematical
expressions are evaluated by Qalculate in the same input; `Enter` copies a
displayed result to the clipboard. Arithmetic such as `2 + 2` works directly.
Prefix richer expressions with `=` or `calc `, for example
`= 10 km to miles`. This requires the `libqalculate` package, which provides
`qalc`. `Escape` or a click outside the launcher closes it.

The picker can also be controlled through
`qs -c main ipc call launcher show|hide|toggle`.

## Notes

Click the note icon in the top bar to open the anchored card grid beside it.
Press `+` to create a note, then type directly in its card. Cards grow
vertically with their text instead of scrolling internally; the grid scrolls
when it exceeds the popup height. The header buttons pin or delete the note.
Pinned notes become Hyprland-managed floating windows that remain above other
windows, stay editable, grow with their text, and move when their header is
dragged. Pinning again returns the note to the grid only.

Notes are stored in Quickshell's state directory and survive shell reloads.
The view can also be controlled through IPC:

```sh
qs -c main ipc call notes toggle
qs -c main ipc call notes show
qs -c main ipc call notes hide
qs -c main ipc call notes add
```

For example, a Hyprland key binding can open the view with:

```ini
bind = SUPER, N, exec, qs -c main ipc call notes toggle
```

## AI Quick Chat

The AI backend starts with the shell so the sandbox and Codex connection are
ready before the overlay opens. The AI control in the top bar shows startup
state, then requests the remaining weekly subscription allowance through the
same sandbox and its credential proxy. It shows `Ready` when the proxy does not
expose subscription limits. Click the control to open the chat.

Press `Super+A` to open a compact AI chat overlay, or `Super+Shift+A` to select
a screen region and attach its untouched PNG to a new prompt.
The interface is a minimal dark composer that expands into the current
conversation. Its header opens persisted conversation history and exports the
loaded conversation as Markdown. All assistant output from one turn renders as
one Markdown response. Web and email links open externally, use a brighter
browser-style blue, and underline only while hovered. An icon-only whole-answer
copy action appears while a completed answer is hovered, and fenced code renders
in separate blocks with its own copy icons. While Codex is reasoning or using a
tool, a small muted animated text label shows the current work and disappears
when that work finishes; reasoning, command, and tool details are not retained
as visible blocks. Generated regular files appear in a compact card strip with
native Save and delete actions. The footer shows the `sbx` authorization state,
active Codex model and thinking level, and a compact circular send button that
becomes a stop button while a response is streaming. Pasting while the composer
is focused attaches a clipboard image without interfering with normal text
paste. Accepted outgoing messages appear in the conversation immediately with a
`Sending…` status while the backend starts the turn.

Type `/` at the start of the composer or after existing draft text to open the
command palette. Selecting an inline command removes only that command fragment
and preserves the rest of the draft. `/file` hides the chat and opens a
foreground picker for PNG, JPEG, WebP, and text files. `/screenshot` captures
a screen region, `/copy` copies the user and assistant transcript, and
`/export` opens a native save dialog for an atomic Markdown export. `/history`
opens persisted Codex threads. `/pin` appears in popup mode and moves the chat
into a managed
window; `/unpin` appears there instead and returns it to the popup. `/model`
changes the active model, `/thinking` changes reasoning effort, and
`/preset NAME` applies a configured model-and-thinking pair. The selected
model-and-thinking combination persists across shell restarts.
`/new` starts a clean chat without deleting the previous thread or its
generated files. `/reconnect` reloads the chat-only kit and app-server.
`/update` updates Codex inside the existing sandbox, then reconnects without
removing history or generated files. `/rebuild` first warns that it will delete
all sandbox threads and managed outputs; run it a second time within 30 seconds
to perform the destructive rebuild. Model and thinking choices come from
app-server's `model/list` response and are applied to subsequent turns. `Tab`
completes the highlighted command without executing it. `Enter` executes a
complete command immediately, accepts a highlighted partial command, or sends
a message. `Shift+Enter` inserts a newline, and `Escape` hides the overlay
without stopping an active response. A turn completed while visible sends no
notification. A turn completed while hidden sends one privacy-safe desktop
notification whose Open action restores the focused-screen chat and composer.

Define presets in
[`ai-chat/AiPresets.json`](ai-chat/AiPresets.json) using model IDs and thinking
levels shown by `/model` and `/thinking`:

```json
{
  "presets": [
    { "name": "fast", "model": "gpt-5.6-terra", "thinking": "low" }
  ]
}
```

The footer appends a preset name only while both the selected model and thinking
level exactly match it, including when those values were selected manually.
Preset configuration stays on the host and is not copied into the sandbox.

The feature owns one dedicated sandbox named `quickshell-ai-chat`, configured
in [`ai-chat/AiConfig.qml`](ai-chat/AiConfig.qml). It creates that sandbox with
`sbx create codex` and a mode-`0700` private workspace below Quickshell's state
directory.
It never attaches the user's home or a project. Conversation history is the
app-server's persisted thread store; the client neither mirrors nor rewrites
transcripts. History queries require the exact chat working directory and only
source kinds emitted by Codex app-server, so unrelated Codex threads cannot
appear. New Chat interrupts an active turn when needed, clears only the loaded
view, and leaves the previous thread available in History. The embedded
app-server disables Codex's startup update prompt. Codex therefore changes only
when `/update` is run. That update remains
in the current container; recreating the sandbox restores the bundled version
before `/rebuild` immediately updates it again.
Credentials remain managed by Docker Sandboxes and are not copied into the
Quickshell process or private workspace. Confirm Codex access with:

```sh
sbx run codex
```

The host needs the official Arch packages `quickshell`, `grim`, `slurp`,
`wl-clipboard`, `file`, `zenity`, `libnotify`, and `python`, plus Docker
Sandboxes (`sbx`).
The bundled `ai-chat/AiSbx.sh` launcher resolves the official
`~/.docker/sbx/bin/sbx` installation first, then `~/.local/bin/sbx`, then the
inherited `PATH`. Set `QUICKSHELL_SBX_EXECUTABLE` to an absolute executable
path to override detection.
Check the selected sandbox and installed protocol before starting Quickshell:

```sh
sbx ls
sbx exec quickshell-ai-chat sh -lc 'codex --version'
sbx exec quickshell-ai-chat sh -lc 'codex app-server --help'
```

Sandbox checks stop after 20 seconds, workspace preparation after 15 seconds,
and first-time sandbox creation after five minutes. A timeout stops the stuck
`sbx` process and shows a recovery command; resolve sign-in, daemon, network,
or filesystem problems in a terminal, then run `/reconnect`.

### Chat-only instructions and skills

[`ai-chat/AiChatKit`](ai-chat/AiChatKit) is the editable configuration copied
into only the `quickshell-ai-chat` sandbox. Quickshell replaces
`$HOME/quickshell-ai-chat-kit` from that folder before every app-server start
and uses it as Codex's working directory. `ai-chat/AiChatKit/AGENTS.md`
supplies the always-on custom instructions, including the managed final-output
path `/home/agent/quickshell-ai-outputs`. Add chat-only skills as
`ai-chat/AiChatKit/.agents/skills/<skill-name>/SKILL.md`; supporting scripts,
references, and assets can stay beside each `SKILL.md`.

Run `/reconnect` after editing the kit. Use `/new` as well when instructions
must apply to a fresh thread. The kit is copied rather than mounted: sandbox
changes to its copy are discarded by the next reconnect, while host edits
remain durable in the Quickshell configuration.

### Sandbox maintenance

`/update` preserves the current sandbox, app-server threads, and generated
files while updating Codex, then reloads the kit and resumes the selected
thread without appending stale local messages. `/rebuild` is destructive: after
the second confirmation command, it clears the loaded chat, removes the
dedicated sandbox and its thread store, resets the private host workspace and
managed outputs, recreates the sandbox, updates Codex, and reloads the
chat-only kit.

The pin button beside the chat close button switches the centered overlay into
a standard toplevel window managed by the compositor. While pinned, `ai toggle`
keeps that single window open instead of opening or hiding another chat.
Unpinning returns the same composer and conversation to the overlay; closing
the chat resets it to unpinned mode.

Available IPC calls are:

```sh
qs -c main ipc call ai toggle
qs -c main ipc call ai open
qs -c main ipc call ai close
qs -c main ipc call ai pin
qs -c main ipc call ai unpin
qs -c main ipc call ai screenshot
qs -c main ipc call ai newChat
qs -c main ipc call ai history
qs -c main ipc call ai exportChat
```

The export and artifact helpers return completion, cancellation, and failure
through token-checked `ai` IPC callbacks. Those callbacks are internal to the
helpers; cancellation changes neither the loaded chat nor its existing error
state. Conversation export staging stays below the private user runtime
directory and is unlinked before the save dialog opens.

Set `QUICKSHELL_AI_DEBUG=1` to log sanitized lifecycle diagnostics. Prompt
text, response bodies, attachment contents, credentials, and complete account
objects are never logged.

Codex runs with `approvalPolicy: never` and `dangerFullAccess` inside its
Docker sandbox. It may execute commands, modify the container filesystem, and
access the network without approval. The client still declines any approval or
permission request and exposes no host-side shell controls. `dangerFullAccess`
disables Codex's nested sandbox only; it does not disable Docker Sandboxes
isolation.

The Docker sandbox is the host security boundary. This feature mounts only its
dedicated mode-`0700` workspace below Quickshell's state directory; that
workspace contains only managed generated outputs and is reset before sandbox
creation. It does not mount the user's home or a project. The chat kit is
explicitly copied into the container before Codex starts. The only other host
content transferred is a screenshot, clipboard image, or filesystem image or
text file explicitly selected by the user.

Screenshot callbacks accept only helper-style PNG names. Clipboard and picker
imports are copied first to private helper-style attachment names. Imported
files must be regular PNG, JPEG, WebP, or text files directly inside the
private runtime directory before Quickshell copies them to
`/tmp/quickshell-ai` in the sandbox. Text attachments receive a controlled
`.txt` sandbox name and are presented to Codex by that sandbox path. The
original picker file is never modified or removed. Sandbox copies are removed
after turn completion. Managed host copies remain only while displayed, are
removed by New Chat, and abandoned copies are removed on the next Quickshell
start.

Final generated files live below `outputs/<thread-id>` in the private mounted
workspace. Before a turn, Quickshell points the stable sandbox path
`/home/agent/quickshell-ai-outputs` at only that thread's directory. Discovery
walks the host-visible managed directory without following symlinks and offers
only individual regular files up to 100 MiB; devices, sockets, FIFOs,
out-of-root paths, symlinks, and oversized files never receive Save cards.
Saving reopens the source with no-follow directory traversal and atomically
replaces the user-selected destination, preserving source bytes and leaving
the managed source intact. New Chat retains outputs. A successful explicit
thread deletion removes that thread's output directory; `/rebuild` removes all
managed outputs with the sandbox history.

OAuth uses Docker's credential proxy; the raw subscription token remains
host-side. The app-server necessarily communicates with the Codex service, so
this is not an offline feature. Model-provided Markdown image and raw-HTML
syntax is neutralized before display so assistant output cannot make
Quickshell load arbitrary host files or remote image URLs. Only `http`,
`https`, and `mailto` links are passed to the system URL handler.

## Bar controls

- Media: shows the active track as a plain bar label. Click it for artwork,
  metadata, and previous, play/pause, and next controls.
- Privacy: colored dots appear while the microphone, camera, or screen sharing
  is active (red, orange, and purple respectively).
- Sound: click to open output and input volume controls, device pickers, and
  per-application playback sliders. Right-click the widget to mute or unmute
  output and input together, or scroll over it to change output volume in 5%
  steps. Right-click any slider to mute only that channel.
- Bluetooth: click to open the device popup. It scans while open, keeps
  connected and paired devices first, and supports pairing, connection,
  trust, and confirmed forgetting; right-click the widget to toggle power.
- Network: click to manage Wi-Fi scanning and connections, including joining a
  secured network; right-click to toggle Wi-Fi power directly. Wired status is
  shown automatically when Ethernet is connected.
- Language: shows the active keyboard layout as a two-letter language code and
  updates immediately when the layout changes.
- AI: shows sandbox and Codex connection progress, then the remaining weekly
  subscription allowance when the sandbox exposes it. Click it to open chat.
- Notes: click the note icon to open the anchored, editable card grid. Its
  yellow dot indicates that at least one note is pinned.
- Calendar: click the clock to open a monthly calendar. Use the arrows to move
  between months or click the month title to return to today.

The controls use Quickshell's native MPRIS, PipeWire, and BlueZ integrations.
The language indicator queries Hyprland once at startup and then follows its
keyboard layout events.
