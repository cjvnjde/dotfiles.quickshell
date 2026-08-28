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
