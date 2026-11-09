# Quickshell

## Islands
- Independent `*Island.qml` components own contents, sizing, interactions, and popups. Pass explicit dependencies and palette/font properties; never reach into parents or siblings.
- `Bar.qml` owns layout, click-through input masks, stacking, and popup coordination. Audio/calendar expose `open` and `opened()`; opening one closes the other. Popups take a `target`, sit 4px below it, and dismiss on Escape/outside click.
- Geometry: 24px bar, 20px islands, 4px outer margins/gaps; transparent between islands. Keep `exclusiveZone: 0`; special workspaces change stacking, not geometry. Hide empty tray/status islands.
- Share privacy tracking and keep-awake state in `shell.qml`, not per monitor.

## Style
**AudioPopup.qml / AudioControl.qml are the visual reference. Preserve their compact, quiet, flat look.** No oversized pills, heavy outlines, shadows, gradients, or decorative animation.

Catppuccin Mocha:

| Role | Color |
|---|---|
| Background / darker inset | `#1e1e2e` / `#181825` |
| Hover, raised surface, card border | `#313244` |
| Slider track / text selection | `#45475a` / `#585b70` |
| Primary / secondary / muted text | `#cdd6f4` / `#a6adc8` / `#6c7086` |
| Accent, active controls | `#b4befe` (lavender) |
| Bluetooth / activity / screen capture | `#89b4fa` / `#a6e3a1` / `#fab387` |
| Muted audio control or mic / muted speaker badge | `#f38ba8` / `#f9e2af` |

- **Radii:** islands 6px; popup/launcher cards 5px; controls, cells, tooltips 4px. Card borders: 1px `#313244`. Tooltips: raised `#313244` background, `#45475a` border.
- **Spacing:** popup padding 12px, internal gaps usually 4–6px, audio sections 10px apart. Size to content; retain the calendar grid and larger launcher layout.
- **Fonts:** `sans-serif` 11px for popup labels, secondary text, tooltips, workspace numbers; 12px calendar headings/dates. `FiraCode Nerd Font` 12px bar text/icons; launcher 14px text, 16px search/tool glyphs. Bold sparingly.
- **States:** transparent controls, `#313244` hover/open; lavender active/selected fills with background-colored text. Launcher selection stays muted. Preserve semantic status colors, accessible names, and hover hints.
- **Audio proportions:** 24px first-row controls, 3px slider track, 8px circular handle; secondary percentages and elided device names.

Run `qs` and inspect affected surfaces after styling changes. Reuse existing patterns; do not introduce another theme system or unrelated behavior changes.
