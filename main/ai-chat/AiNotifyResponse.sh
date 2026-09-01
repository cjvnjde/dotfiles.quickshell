#!/usr/bin/env bash
set -u

if [[ $# -ne 1 ]] || ! command -v notify-send >/dev/null 2>&1; then
  exit 0
fi

conversation_title="${1//$'\n'/ }"
conversation_title="${conversation_title//$'\r'/ }"
conversation_title="${conversation_title//$'\t'/ }"
conversation_title="${conversation_title:0:120}"

action="$(notify-send --app-name='Quickshell AI Quick Chat' \
  --urgency=normal --expire-time=10000 --action=open=Open -- \
  'Codex response ready' "$conversation_title" 2>/dev/null)" || exit 0

if [[ "$action" == 'open' ]] && command -v qs >/dev/null 2>&1; then
  qs -c main ipc call ai open >/dev/null 2>&1 || true
fi
