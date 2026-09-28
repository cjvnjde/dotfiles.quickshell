# Hover bar

An Omarchy-inspired layout built on this shell's existing controls. The design reference is [Omarchy's bar at 947e2fc](https://github.com/omacom/omarchy/tree/947e2fc002d6831c7888b29b5761d59d29e69727/shell/plugins/bar): a fixed center clock, hover-revealed inactive actions, persistent active indicators, understated workspace numbers, and a drawer on the right. This is a local implementation, not Omarchy's plugin host; Omarchy manifests and its CLI are not required or loaded.

## Using it

- Left: workspaces 1–5 plus additional open workspaces on this monitor. The selected workspace becomes a solid mark; empty workspaces are dim. Click to switch.
- Center: hover the clock to reveal Do Not Disturb, screenshot, and recording buttons. Click the clock for the calendar; Escape closes the calendar.
- Screenshot: left click selects a region; right click captures the full desktop. PNGs are saved under the XDG Pictures directory's `Screenshots` folder and copied to the Wayland clipboard. Escape cancels region selection.
- Recording: left click selects a region; right click records this display. Click the red timer to stop and save. Videos go under the XDG Videos directory's `Recordings` folder. Recording is silent, H.264, 30 fps, using CPU encoding suitable for this Virgl VM. The timer stays visible outside hover, and recording survives shell reloads.
- Right: hover to reveal appearance, Bluetooth, tray icons, and agent usage (when available). Audio and network remain on the right. Keyboard layout and weather sit immediately after the centered clock, following Omarchy’s center order. Existing clicks, audio wheel volume, and right-click mute are preserved. Bluetooth/agent widgets remain visible while their panels are open.
- Drawers stay revealed while moving across the bar and close 280 ms after leaving it. Hover only reveals buttons; opening a settings panel still takes a click.

The bar keeps the existing Catppuccin theme and uses a flat 32-pixel surface. It does not import unrelated Omarchy tools or services. Existing screenshot keyboard shortcuts are unchanged.

## Imported plugin refinements

Notifications now use Omarchy’s full service and toast card, with only host/theme/path adapters. Our custom center and right-side bell have been removed. History replays the latest ten toast cards using Super+Shift+Alt+comma; DND is in the center hover indicators. See `../notifications/README.md` for exact behavior, upstream shortcuts, and attribution. Workspace hover changes the text color; it no longer paints a full-height oval.

Network and Bluetooth were already Omarchy-derived panels in this checkout. Their native Quickshell backends remain in use. Both now use compact bar icons with hover information; click a network detail row to copy its value. Bluetooth device operations need an actual adapter, which this VM currently lacks.

Weather is always present in the center, immediately after the clock and keyboard-layout widget. Its popup uses Omarchy's weather model/helpers with an Open-Meteo backend. Open it, enter a city and press Enter, then choose the matching location. It shows current conditions, feels-like temperature, humidity, wind, and the next three days in Celsius. The city and cached forecast live in Quickshell's `weather.json` state file. Data refreshes every 30 minutes and on demand. Errors retain cached data with an error message and update timestamp. No location is inferred from the IP address; the default is unconfigured. No API key or extra packages are needed. Attribution is in `../notifications/OMARCHY-LICENSE`.

Weather IPC: `qs ipc -c main call weather search CITY`, `choose INDEX` (zero-based), `status`, and `clear`. Search results are also selectable in the popup. Source: [Omarchy weather model at the pinned revision](https://github.com/omacom/omarchy/blob/947e2fc002d6831c7888b29b5761d59d29e69727/shell/plugins/panels/weather/Model.js).

## Modules and configuration

Edit `../bar.json` to place modules in `left`, `center`, and `right` arrays. Order in each array is screen order. Entries accept `id`, `enabled` (default true), `reveal` (`always` or `hover`), and a module-specific `settings` object. For example:

```json
{"id": "example", "reveal": "hover", "settings": {"label": "Open terminal"}}
```

`centerAnchor` names an always-visible center module whose middle stays at the screen center as neighbors expand; omit it to center the whole section. The default anchor is `clock`. The default weather position remains after clock and keyboard. Workspace settings accept `persistent: [1,2,3,4,5]`; clock settings accept `format: "ddd  HH:mm"`.

Config edits apply live. Invalid JSON/schema keeps the working layout; a last-known-good copy in Quickshell state also covers restarting with an invalid config. A broken/missing module is isolated to its slot and reported by `bar status`. Module IDs must be unique lowercase names; arbitrary file paths are not accepted. Keep the combined module widths within your screen width.

Every module lives in `../modules/<id>/`, with its own `Widget.qml`, `qmldir`, models, and helper scripts. Copy `../modules/example/` to a new lowercase directory, change its widget, then add its ID to any section in `bar.json`. No host registry or TopBar edit is needed. See `../modules/README.md` for the widget API.

Shared colors, typography, dimensions, and animation timing come from `../Theme.qml`. Common `BarModule`, `BarButton`, and `InputField` components live in `../components/`. Weather, Wi-Fi password, and launcher inputs share the same vertically centered text and placeholder implementation. The upstream notification service stays separate in `../notifications/`; it is not a custom notification-center module.

Quickshell normally reloads watched files automatically. After adding files or changing imports, force a complete reload:

```sh
qs ipc -c main call bar reload
```

`qs ipc -c main call bar status` reports the drawer state; `qs log -c main -t 30` shows loading errors. Failed QML reloads preserve the last working UI. All screens share `CaptureService`, and the recording process runs in the transient `quickshell-bar-recording.service` user unit. To stop it independently of the shell:

```sh
systemctl --user stop quickshell-bar-recording.service
```

Capture dependencies: `python`, `grim`, `slurp`, `wl-clipboard`, `xdg-user-dirs`, `libnotify`, and `wf-recorder` with H.264 support. Only `wf-recorder` was added to this VM. Check recording logs with `journalctl --user -u quickshell-bar-recording`.

## Backups

The complete pre-modular bar, notification files, Theme, launcher, and shell entry point are archived in `~/.local/state/vm-setup/modular-before/quickshell.tgz`. Earlier original-layout files remain in `bar-before/`. Restore a consistent backup as a unit when rolling back; individual files from the old flat layout reference paths that moved into module folders. No changes were pushed.
