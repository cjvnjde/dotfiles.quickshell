# Omarchy notifications

This is the notification service and toast UI from [Omarchy revision 947e2fc002d6831c7888b29b5761d59d29e69727](https://github.com/omacom/omarchy/tree/947e2fc002d6831c7888b29b5761d59d29e69727/shell/plugins/notifications). MIT license: `OMARCHY-LICENSE`.

`NotificationOverlay.qml` is upstream `Service.qml`; `ToastCard.qml` is upstream `components/NotificationCard.qml`. Compatibility changes are limited to local imports, Theme color/font tokens, the standard two-pixel border renderer, bar height, state paths, and the app-focus helper. `NotificationStyle.qml` reads compositor rounding and gaps using the same formulas as Omarchy. `NotificationLogic.js` is the upstream logic. There is no custom notification center, header, tabs, metadata row, countdown line, or separate action-button row.

## Behavior

Notifications appear as passive, click-through-except-for-cards, top-right toast stacks on each monitor. Left-click invokes the default action or focuses the sending app; right-click or the hover close dismisses. Low/normal messages display for at least 5/8 seconds, longer if requested up to 30 seconds; critical messages persist. Hover pauses expiry and content replacement restarts it. These are upstream rules, including normal zero-timeout messages using the normal minimum lifetime.

History replays the most recent ten archived messages as the same toast cards. It is not a separate panel. Live popups and local images are persisted and restored across shell reloads. State lives under `Quickshell.stateDir/omarchy-notifications/`, with one JSON file per popup/history item. The previous `notification-history.json` remains untouched as a legacy backup; migration copies at most its latest ten entries without deleting older data.

DND follows upstream behavior: only `omarchy-action` messages and critical messages from `notify-send` bypass it. Silenced non-ephemeral messages go to history; transient/CLI confirmation messages are dropped. Toggle DND using the center hover indicator or shortcut below.

## Omarchy shortcuts

Installed in this VM's ignored `~/.config/hypr/modules/local.lua`:

| Shortcut | Action |
| --- | --- |
| Super+, | Dismiss latest |
| Super+Shift+, | Dismiss all |
| Super+Ctrl+, | Toggle DND |
| Super+Alt+, | Invoke latest notification |
| Super+Shift+Alt+, | Replay history |

Equivalent IPC: `qs ipc -c main call notifications showHistory`, `dismissOne`, `dismissAll`, `invokeLast`, `toggleDnd`, `dndState`, `clear` (history only), or `ping`.

`FocusApp.sh` is Omarchy's app-focus helper, called through Bash with a structured argument array. The whole Omarchy shell is not required. Existing theme, paths, and Lua Hyprland session are preserved.
