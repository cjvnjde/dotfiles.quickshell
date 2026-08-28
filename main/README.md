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

## Application picker

Press `Super+T` to open the centered application picker. Type to filter
installed desktop applications, use `Up`/`Down` to select one, and press
`Enter` to launch it. `Escape` or a click outside the picker closes it.

The picker intentionally contains applications only. It can also be controlled
through `qs -c main ipc call launcher show|hide|toggle`.

## Bar controls

- Media: shows the active track as a plain bar label. Click it for artwork,
  metadata, and previous, play/pause, and next controls.
- Privacy: colored dots appear while the microphone, camera, or screen sharing
  is active (red, orange, and purple respectively).
- Sound: click to open the volume slider, right-click to mute, or scroll over
  the widget to change volume in 5% steps.
- Bluetooth: click to manage power, discovery, pairing, and connections;
  right-click the widget to toggle Bluetooth power directly.
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
