# Adding a bar module

1. Copy `example/` to a lowercase folder such as `my-widget/`.
2. Edit its `Widget.qml`; keep `qmldir` registering `Widget 1.0 Widget.qml`.
3. Add `{"id":"my-widget"}` to `left`, `center`, or `right` in `../bar.json`.
4. New files/imports may need `qs ipc -c main call bar reload`.

The loader creates `modules/<id>/Widget.qml` directly. No registry is needed. Store that module’s QML controls, JS models, and Python helpers alongside it; resolve scripts with `Quickshell.shellPath("modules/my-widget/helper.py")`.

## Widget contract

Extend `BarModule` from `../../components`. Set `implicitWidth`; zero hides an empty module. The host sets `bar` (the PanelWindow with screen/controllers) and `settings` before component construction. `settings.section` defaults to the configured section. Set `available: false` when unsupported. Set `active: true` during recording or while a panel is open to keep a hover-only module visible when the section folds. Let the host manage slot visibility and width.

Import `"../.."` for `Theme`. Use its colors/font sizes/layout tokens, and use `BarButton` for consistent icons/hover/tooltips and `InputField` for text entry. The notification font has a separate token so upstream cards retain their original appearance.

Modules remain instantiated while folded; keep background work light. Use shared singleton services for work spanning screens (the `capture/` directory is a backend shared by screenshot and recording, not a visible module). Use argument arrays with `Quickshell.execDetached` and avoid interpolated shell commands. Modules execute as the desktop user.

## Checks

`qs ipc -c main call bar status` reports config errors, per-module load failures, loaded slots, and geometry. `qs log -c main -t 30` gives QML details. Layout validation tests: `node --test topbar/layout.test.cjs` from `main/`.
