#!/usr/bin/env bash
set -euo pipefail

sandbox_name="${1:?sandbox name is required}"
workspace="${2:?workspace path is required}"
project_id="${3:?project ID is required}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
kit_dir="$script_dir/AiChatKit"
global_codex_dir="$script_dir/local/global/.codex"
project_codex_dir="$script_dir/local/projects/$project_id/.codex"

if [[ ! -d "$kit_dir" ]]; then
  printf '%s\n' 'AI chat kit directory is missing' >&2
  exit 1
fi
if [[ "$workspace" != /* ]]; then
  printf '%s\n' 'AI sandbox workspace path must be absolute' >&2
  exit 1
fi
if [[ ! "$project_id" =~ ^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$ ]]; then
  printf 'Invalid AI project ID: %s\n' "$project_id" >&2
  exit 1
fi
if [[ "$project_id" != "general" && ! -d "$project_codex_dir" ]]; then
  printf 'AI project configuration is missing: %s\n' "$project_id" >&2
  exit 1
fi

umask 077
install -d -m 700 -- "$workspace"
python3 "$script_dir/AiOutputs.py" ensure "$workspace/outputs"

package_staging="$(mktemp -d "$workspace/.quickshell-ai-chat-kit.XXXXXX")"
trap 'rm -rf -- "$package_staging"' EXIT
cp -a -- "$kit_dir/." "$package_staging/"
install -d -m 700 -- "$package_staging/.agents/skills"
effective_config="$package_staging/.quickshell-ai-codex-config.toml"
: > "$effective_config"

apply_codex_layer() {
  local layer="$1"
  local label="$2"
  if [[ ! -d "$layer" ]]; then
    return
  fi
  if [[ -f "$layer/AGENTS.md" ]]; then
    printf '\n\n# %s instructions\n\n' "$label" \
      >> "$package_staging/AGENTS.md"
    cat -- "$layer/AGENTS.md" >> "$package_staging/AGENTS.md"
  fi
  if [[ -d "$layer/skills" ]]; then
    local skill
    for skill in "$layer/skills"/*; do
      [[ -e "$skill" || -L "$skill" ]] || continue
      rm -rf -- "$package_staging/.agents/skills/$(basename -- "$skill")"
      cp -a -- "$skill" "$package_staging/.agents/skills/"
    done
  fi
  if [[ -f "$layer/config.toml" ]]; then
    {
      printf '\n# %s MCP configuration\n' "$label"
      cat -- "$layer/config.toml"
      printf '\n'
    } >> "$effective_config"
  fi
}

apply_codex_layer "$global_codex_dir" "Global"
if [[ "$project_id" != "general" ]]; then
  apply_codex_layer "$project_codex_dir" "Project $project_id"
fi

# Variables in this script fragment belong to the sandbox shell.
# shellcheck disable=SC2016
tar -C "$package_staging" -cf - . | "$script_dir/AiSbx.sh" exec -i "$sandbox_name" sh -c '
  set -eu
  target="$HOME/quickshell-ai-chat-kit"
  target_staging="$(mktemp -d "$HOME/.quickshell-ai-chat-kit.XXXXXX")"
  codex_source="$target_staging/.quickshell-ai-codex-config.toml"
  codex_target="$HOME/.codex/config.toml"
  codex_base="$HOME/.quickshell-ai-base-codex-config.toml"
  codex_staging="$(mktemp "$HOME/.codex/.quickshell-ai-config.XXXXXX")"
  codex_base_staging=

  cleanup() {
    rm -rf -- "$target_staging"
    rm -f -- "$codex_staging"
    if [ -n "$codex_base_staging" ]; then
      rm -f -- "$codex_base_staging"
    fi
  }
  trap cleanup EXIT

  tar -xf - -C "$target_staging"
  if [ ! -f "$codex_base" ]; then
    codex_base_staging="$(mktemp "$HOME/.quickshell-ai-base-codex-config.XXXXXX")"
    if [ -f "$codex_target" ]; then
      cp -- "$codex_target" "$codex_base_staging"
    fi
    chmod 600 "$codex_base_staging"
    mv -- "$codex_base_staging" "$codex_base"
    codex_base_staging=
  fi

  cat -- "$codex_base" > "$codex_staging"
  printf "\n" >> "$codex_staging"
  cat -- "$codex_source" >> "$codex_staging"
  chmod 600 "$codex_staging"
  rm -f -- "$codex_source"

  mv -- "$codex_staging" "$codex_target"
  rm -rf -- "$target"
  mv -- "$target_staging" "$target"
  trap - EXIT
'

rm -rf -- "$package_staging"
trap - EXIT
