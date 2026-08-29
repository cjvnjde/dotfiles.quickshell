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

## AI Quick Chat

Press `Super+A` to open a compact AI chat overlay, or `Super+Shift+A` to select
a screen region and attach its untouched PNG to a new prompt. The interface is
a minimal dark composer that expands into the current conversation. Its footer
shows the `sbx` authorization state, active Codex model and thinking level, and
a compact circular send button that becomes a stop button while a response is
streaming. Pasting while the composer is focused attaches a clipboard image
without interfering with normal text paste.

Type `/` at the start of the composer or after existing draft text to open the
command palette. Selecting an inline command removes only that command fragment
and preserves the rest of the draft. `/file` hides the chat and opens a
foreground picker for PNG, JPEG, WebP, and text files. `/ps` captures a screen
region, `/model` changes the active model, `/thinking` changes reasoning effort,
`/new` starts a clean chat, and `/reconnect` restarts the backend. Model and
thinking choices come from app-server's `model/list` response and are applied
to subsequent turns. `Enter` executes a complete command immediately, accepts
a highlighted partial command, or sends a message. `Shift+Enter` inserts a
newline, and `Escape` hides the overlay without stopping an active response.
The current in-memory conversation is preserved while the overlay is hidden.

The feature owns one dedicated sandbox named `quickshell-ai-chat`, configured
in [`AiConfig.qml`](AiConfig.qml). It creates that sandbox with `sbx create
codex` and an otherwise empty private workspace below Quickshell's state
directory. It never attaches the user's home or a project. New Chat deletes the
previous Codex thread through app-server while keeping the sandbox and
app-server connection alive, so the next message can start immediately.
Credentials remain managed by Docker Sandboxes and are not copied into the
Quickshell process or private workspace. Confirm Codex access with:

```sh
sbx run codex
```

The host needs the official Arch packages `quickshell`, `grim`, `slurp`,
`wl-clipboard`, `file`, and `zenity`, plus Docker Sandboxes (`sbx`).
Check the selected sandbox and installed protocol before starting Quickshell:

```sh
sbx ls
sbx exec quickshell-ai-chat codex --version
sbx exec quickshell-ai-chat codex app-server --help
schema_dir="$(mktemp -d)"
sbx exec quickshell-ai-chat codex app-server generate-ts --out "$schema_dir/ts"
sbx exec quickshell-ai-chat codex app-server generate-json-schema --out "$schema_dir/json"
```

Available IPC calls are:

```sh
qs -c main ipc call ai toggle
qs -c main ipc call ai open
qs -c main ipc call ai close
qs -c main ipc call ai screenshot
qs -c main ipc call ai newChat
```

Set `QUICKSHELL_AI_DEBUG=1` to log sanitized lifecycle diagnostics. Prompt
text, response bodies, attachment contents, credentials, and complete account
objects are never logged.

Codex remains a coding agent and may run read-only commands inside its Docker
sandbox. The client requests `approvalPolicy: never` and a read-only sandbox
policy, declines command and file-change approvals, grants no requested
permissions, and exposes no host-side shell controls. These controls restrict
the agent inside the sandbox; they do not remove Codex's built-in shell tool.

The Docker sandbox is the host security boundary. This feature mounts only its
dedicated, mode-`0700` empty workspace below Quickshell's state directory; that
workspace is reset before sandbox creation. It does not mount the user's home
or a project. The only other host content transferred is a screenshot,
clipboard image, or filesystem image or text file explicitly selected by the
user.

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

OAuth uses Docker's credential proxy; the raw subscription token remains
host-side. The app-server necessarily communicates with the Codex service, so
this is not an offline feature. Model-provided Markdown image and raw-HTML
syntax is neutralized before display so assistant output cannot make
Quickshell load arbitrary host files or remote image URLs.

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
- Calendar: click the clock to open a monthly calendar. Use the arrows to move
  between months or click the month title to return to today.

The controls use Quickshell's native MPRIS, PipeWire, and BlueZ integrations.
The language indicator queries Hyprland once at startup and then follows its
keyboard layout events.
