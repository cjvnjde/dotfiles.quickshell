#!/usr/bin/env bash
set -Eeuo pipefail

readonly action="${1:-}"
readonly address="${2:-}"

if [[ "$action" != "connect" && "$action" != "disconnect" ]]; then
  printf 'Usage: %s <connect|disconnect> <address>\n' "${0##*/}" >&2
  exit 2
fi

if [[ ! "$address" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]]; then
  printf 'Invalid Bluetooth address: %s\n' "$address" >&2
  exit 2
fi

run_bluetoothctl() {
  local duration="$1"
  shift
  timeout --foreground --kill-after=2s "$duration" bluetoothctl "$@"
}

case "$action" in
  connect)
    # Trust first so BlueZ can complete profile setup and future reconnects.
    run_bluetoothctl 5s trust "$address" >/dev/null 2>&1 || true
    run_bluetoothctl 20s connect "$address"
    ;;
  disconnect)
    run_bluetoothctl 10s disconnect "$address"
    ;;
esac
