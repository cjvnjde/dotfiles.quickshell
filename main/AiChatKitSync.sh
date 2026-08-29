#!/usr/bin/env bash
set -euo pipefail

sandbox_name="${1:?sandbox name is required}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
kit_dir="$script_dir/AiChatKit"

if [[ ! -d "$kit_dir" ]]; then
  printf 'AI chat kit directory is missing: %s\n' "$kit_dir" >&2
  exit 1
fi

tar -C "$kit_dir" -cf - . | "$script_dir/AiSbx.sh" exec -i "$sandbox_name" sh -c '
  set -eu
  target="$HOME/quickshell-ai-chat-kit"
  staging="$(mktemp -d "$HOME/.quickshell-ai-chat-kit.XXXXXX")"
  trap '\''rm -rf -- "$staging"'\'' EXIT
  tar -xf - -C "$staging"
  rm -rf -- "$target"
  mv -- "$staging" "$target"
  trap - EXIT
'
