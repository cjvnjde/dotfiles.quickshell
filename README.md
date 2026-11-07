# Quickshell

Minimal Quickshell config. `setup.sh` links this folder to `~/.config/quickshell`,
so `shell.qml` is the default config: run it with plain `qs`.

| File | What it does |
|---|---|
| `shell.qml` | Entry point: wallpaper and bar on each monitor, plus the launcher |
| `Wallpaper.qml` | Desktop background: shows `wallpaper.jpg` on every monitor |
| `wallpaper.jpg` | The background image (replace it to change the wallpaper) |
| `BarTooltip.qml` | Hover hints for bar items (own popup, not clipped by the 24px bar) |
| `Bar.qml` | Transparent Catppuccin Mocha island bar: fixed workspaces 1–5 plus higher workspaces on demand, Bluetooth/privacy badges, sound controls, 12-hour clock |
| `CalendarPopup.qml` | Click-clock calendar: opens at this month with today selected; month navigation and Today reset |
| `PrivacyState.qml` | Shared PipeWire activity probe and default speaker/microphone mute state |
| `AudioPopup.qml` | Sound popup with output/input controls and a full-mixer shortcut |
| `AudioControl.qml` | PipeWire volume slider, mute button, and device picker |
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

The sound island beside the clock always shows output volume. Click it for speaker
and microphone volume sliders, mute buttons, and default-device selection. Scroll
over the island to change output volume in 5% steps; middle-click to toggle speaker
mute. Sliders and scrolling are capped at 100%. Click **Mixer ↗** for
`pavucontrol`, including per-application controls. Outside click or Escape closes
the popup. Volume and mute state follow PipeWire changes, including keyboard shortcuts.

Quickshell 0.3.2 does not expose volume controls for nodes classified as
`Audio/Source/Virtual` (including some EasyEffects sources). Use **Mixer ↗**
for devices unavailable in this picker.

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
