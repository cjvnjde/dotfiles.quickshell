#!/usr/bin/env bash
set -euo pipefail

sandbox_name="${1:?sandbox name is required}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
weekly_filter='[.rate_limit.primary_window, .rate_limit.secondary_window]
  | map(select(.limit_window_seconds == 604800))
  | first
  | 100 - .used_percent'

# `$1` belongs to the sandbox shell.
# shellcheck disable=SC2016
exec "$script_dir/AiSbx.sh" exec "$sandbox_name" sh -c \
  'curl -fsS https://chatgpt.com/backend-api/wham/usage | jq -er "$1"' \
  sh "$weekly_filter"
