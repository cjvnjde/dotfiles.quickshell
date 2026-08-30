#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  exit 2
fi

sandbox_name="$1"
workspace="$2"
thread_id="$3"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! "$thread_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]]; then
  exit 2
fi
if [[ "$workspace" != /* ]]; then
  exit 2
fi

outputs_root="$workspace/outputs"
thread_root="$outputs_root/$thread_id"
umask 077
install -d -m 700 -- "$workspace"
python3 "$script_dir/AiOutputs.py" prepare "$outputs_root" "$thread_id"

# Variables in this script fragment belong to the sandbox shell.
# shellcheck disable=SC2016
"$script_dir/AiSbx.sh" exec "$sandbox_name" sh -c '
  set -eu
  target=$1
  link=$HOME/quickshell-ai-outputs
  if [ ! -d "$target" ]; then
    exit 1
  fi
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    exit 1
  fi
  rm -f -- "$link"
  ln -s -- "$target" "$link"
' sh "$thread_root"
