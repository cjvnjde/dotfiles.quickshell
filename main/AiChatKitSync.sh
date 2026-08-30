#!/usr/bin/env bash
set -euo pipefail

sandbox_name="${1:?sandbox name is required}"
workspace="${2:?workspace path is required}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
kit_dir="$script_dir/AiChatKit"

if [[ ! -d "$kit_dir" ]]; then
  printf '%s\n' 'AI chat kit directory is missing' >&2
  exit 1
fi
if [[ "$workspace" != /* ]]; then
  printf '%s\n' 'AI sandbox workspace path must be absolute' >&2
  exit 1
fi

umask 077
install -d -m 700 -- "$workspace"
python3 "$script_dir/AiOutputs.py" ensure "$workspace/outputs"

# Variables in this script fragment belong to the sandbox shell.
# shellcheck disable=SC2016
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
