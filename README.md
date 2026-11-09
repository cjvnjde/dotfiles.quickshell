# Quickshell

Minimal Quickshell config. `setup.sh` links this folder to `~/.config/quickshell`,
so `shell.qml` is the default config: run it with plain `qs`.

| File | What it does |
|---|---|
| `shell.qml` | Entry point: wallpaper and bar on each monitor, plus the launcher |
| `Wallpaper.qml` | Desktop background: shows `wallpaper.jpg` on every monitor |
| `wallpaper.jpg` | The background image (replace it to change the wallpaper) |
| `BarTooltip.qml` | Hover hints for bar items (own popup, not clipped by the 24px bar) |
| `Bar.qml` | Per-monitor island layout, shared palette, input mask, layer selection, and popup coordination |
| `WorkspaceIsland.qml` | Per-monitor active workspace and workspace buttons: fixed 1–5 plus higher workspaces on demand |
| `StatusIsland.qml` | Auto-hiding Bluetooth/privacy/mute badges and their hover hints |
| `KeepAwakeIsland.qml` | Coffee/moon toggle with a Wayland idle inhibitor and shared state across monitors |
| `AudioIsland.qml` | Output volume, scroll/middle-click controls, and ownership of the sound popup |
| `CalendarIsland.qml` | 12-hour clock, minute updates, and ownership of the calendar popup |
| `TrayIsland.qml` | All registered tray apps in one auto-hiding island, with activation, native menus, and hover names |
| `CalendarPopup.qml` | Click-clock calendar: opens at this month with today selected; month navigation and Today reset |
| `PrivacyState.qml` | Shared PipeWire activity probe and default speaker/microphone mute state |
| `AudioPopup.qml` | Compact sound popup with output and microphone controls |
| `AudioControl.qml` | Two-row audio control: mute/label/device picker, then volume slider/percentage |
| `Launcher.qml` | App launcher: type to filter, arrows to move, Enter to open, Esc to close |
| `LauncherSearch.js` | Fuzzy matching, result ranking, and usage weighting |

Open the launcher with `qs ipc call launcher toggle` (Super+Space in Hyprland).

For editor support (qmlls), create an empty `.qmlls.ini` here; Quickshell fills it in on start.

## Launcher

Search applications or executables in PATH. Commands run in Ghostty, and the
window stays open after they exit so the output can be read (press a key to close).
The command list refreshes each time the launcher opens. Command arguments run in Ghostty;
known commands such as `git log` take precedence over automatic calculator detection.
With `qalc` installed, use `= expression`, `calc expression`, or a trailing `=`
to request calculation explicitly. Enter copies the current result.
Arrow keys and PageUp/PageDown wrap through results, including short lists.

## Bar
### Component boundaries

Each `*Island.qml` owns its contents, sizing, interactions, and any popups.
Islands receive explicit palette/font properties rather than reading a parent bar.
`WorkspaceIsland` takes a `screen` and resolves its own Hyprland monitor;
`StatusIsland` takes the shared `privacy` state and observes Bluetooth itself;
`AudioIsland` takes only the tracked default `sink`. The calendar and tray
islands use their own clock and system-tray services respectively.

Audio and calendar islands expose an `open` property and emit `opened()` when
opening. `Bar.qml` closes the other popup and uses those properties for layer
selection; neither island references its sibling or the bar. Popup components
take an explicit `target` item and position themselves below it, matching
`BarTooltip.qml`.

`shell.qml` still owns one `PrivacyState` shared across monitors, so extracting
islands does not duplicate PipeWire polling or default-device tracking.
The keep-awake toggle also shares one state in `shell.qml`; each monitor's
island binds an idle inhibitor to its own bar window.

### Behavior


The bar is 24 logical pixels high (20-pixel islands), with a constant zero
exclusive zone. Hyprland's normal tiled workspaces use a fixed 24-pixel top gap;
scratchpads add a 12-pixel margin below the bar and along the other edges.
Quake-style terminals still start at the screen edge. While a special workspace is open, the bar sits behind windows but remains
visible wherever uncovered; opening the calendar or sound controls temporarily raises it. Only
stacking changes, never monitor reservations or background workspace geometry.

Click workspace numbers to switch; the active workspace is highlighted per monitor.
Workspaces 1–5 are always shown; higher numbered workspaces appear while they
exist and disappear when Hyprland removes them after they become empty and inactive.
Special workspaces and scratchpads never appear. Click the clock to open the calendar; click outside or press Escape
to close it. Select any day, browse months, or click Today to reset.

The leftmost island in the right-hand block groups system tray apps such as Telegram
and Steam. It appears automatically when apps register tray icons and disappears
when none remain; it is not a list of every running process. Left-click activates
an app (or opens its menu for menu-only apps); right-click opens its menu.
Middle-click and scrolling are forwarded to the app. Hover to see the app's name.
Native tray menus require the `UseQApplication` pragma in `shell.qml`; restart
Quickshell once when adding this pragma, since hot reload cannot change application mode.

The moon/coffee island beside the sound controls toggles keep-awake mode.
Moon means normal idle behavior; a highlighted coffee cup means automatic
locking, screen-off, and suspend are inhibited through Wayland, including
Hypridle's configured idle listeners. Click again to restore the usual timeouts.
Manual lock/suspend still work. State is shared across monitors, starts off on
Quickshell startup/reload, and is released automatically when Quickshell exits.

The sound island beside the clock always shows output volume. Click it for output
and microphone controls: each has a mute icon, label, and default-device picker
on the first row, with a volume slider and percentage below. Scroll over the island
to change output volume in 5% steps; middle-click to toggle speaker mute. Sliders
and scrolling are capped at 100%. Outside click or Escape closes the popup.
Volume and mute state follow PipeWire changes, including keyboard shortcuts.

Quickshell 0.3.2 does not expose volume controls for nodes classified as
`Audio/Source/Virtual` (including some EasyEffects sources). Use an external mixer
such as `pavucontrol` for devices unavailable in this picker.

A blue Bluetooth icon appears only while at least one Bluetooth device is connected,
and disappears when the last device disconnects. Connection state updates automatically.

Other status badges appear only for camera/microphone use, screen capture/sharing, or
speaker/microphone mute. Hyprland's Super+M toggles **microphone** mute. Activity is
sampled every two seconds using `pw-dump`; mute state is event-driven. Microphone
activity follows active source links, including effects/filter clients, independently
of default-device mute. Speaker-monitor recordings and inactive links do not count.
Indicators only cover recognizable PipeWire streams, not direct V4L2 camera access
or capture that bypasses PipeWire. They are convenience indicators, not a security guarantee.

## Setup

```bash
bash quickshell/setup.sh enable
```
