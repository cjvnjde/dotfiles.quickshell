# Quickshell

Minimal Quickshell config. `setup.sh` links this folder to `~/.config/quickshell`,
so `shell.qml` is the default config: run it with plain `qs`.

| File | What it does |
|---|---|
| `shell.qml` | Entry point: wallpaper and bar on each monitor, plus the launcher |
| `Wallpaper.qml` | Desktop background: shows `wallpaper.jpg` on every monitor |
| `wallpaper.jpg` | The background image (replace it to change the wallpaper) |
| `Bar.qml` | Top bar: Hyprland workspaces (click to switch) and a clock |
| `Launcher.qml` | App launcher: type to filter, arrows to move, Enter to open, Esc to close |

Open the launcher with `qs ipc call launcher toggle` (Super+T in Hyprland).

For editor support (qmlls), create an empty `.qmlls.ini` here; Quickshell fills it in on start.

## Setup

```bash
bash quickshell/setup.sh enable
```
