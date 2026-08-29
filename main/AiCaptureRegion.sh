#!/usr/bin/env bash
set -u

report_failure() {
  qs -c main ipc call ai screenshotFailed "$1" >/dev/null 2>&1 || true
}

report_cancelled() {
  qs -c main ipc call ai screenshotCancelled >/dev/null 2>&1 || true
}

if ! command -v slurp >/dev/null 2>&1; then
  report_failure 'slurp is unavailable; install the official Arch slurp package'
  exit 1
fi

if ! command -v grim >/dev/null 2>&1; then
  report_failure 'grim is unavailable; install the official Arch grim package'
  exit 1
fi

if ! command -v file >/dev/null 2>&1; then
  report_failure 'file is unavailable; install the official Arch file package'
  exit 1
fi

if ! geometry="$(slurp)"; then
  report_cancelled
  exit 0
fi
if [[ -z "$geometry" ]]; then
  report_cancelled
  exit 0
fi

runtime_root="${XDG_RUNTIME_DIR:-}"
if [[ -z "$runtime_root" ]]; then
  report_failure 'XDG_RUNTIME_DIR is unavailable'
  exit 1
fi

capture_directory="$runtime_root/quickshell-ai"
umask 077
if ! mkdir -p -m 700 "$capture_directory" || ! chmod 700 "$capture_directory"; then
  report_failure 'Could not create the private screenshot directory'
  exit 1
fi

if ! capture_path="$(mktemp --tmpdir="$capture_directory" 'capture-XXXXXXXXXXXX.png')"; then
  report_failure 'Could not allocate a private screenshot file'
  exit 1
fi
if ! grim -g "$geometry" "$capture_path"; then
  rm -f -- "$capture_path"
  report_failure 'grim failed to capture the selected region'
  exit 1
fi

if ! qs -c main ipc call ai attachScreenshot "$capture_path" >/dev/null 2>&1; then
  rm -f -- "$capture_path"
  exit 1
fi
