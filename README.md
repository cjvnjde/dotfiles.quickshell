# Quickshell configuration

This module installs the Quickshell configuration used by the Hyprland setup.
It provides the `main` shell configuration, including the top bar,
notifications, media controls, privacy indicators, sound, Bluetooth, network,
and calendar controls.

## Setup

Install Quickshell, add `quickshell` to the root `.modules` file, and run the
main setup:

```bash
cd ~/dotfiles
bash setup.sh
```

The module links this directory to `~/.config/quickshell`. If that destination
already exists, setup preserves it with a `.bak` suffix (or the next available
numbered backup).

You can also manage the link directly:

```bash
bash quickshell/setup.sh enable
bash quickshell/setup.sh disable
```

Disabling removes only the link managed by this module. Backups are not
restored automatically.

## Run

Start the shell configuration with:

```bash
qs -c main
```

See [`main/README.md`](main/README.md) for the available controls and behavior.
