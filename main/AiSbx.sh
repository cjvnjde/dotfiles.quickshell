#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${QUICKSHELL_SBX_EXECUTABLE:-}" ]]; then
    if [[ -x "$QUICKSHELL_SBX_EXECUTABLE" ]]; then
        exec "$QUICKSHELL_SBX_EXECUTABLE" "$@"
    fi
    printf 'Configured sbx executable is not executable: %s\n' \
        "$QUICKSHELL_SBX_EXECUTABLE" >&2
    exit 127
fi

if [[ -n "${HOME:-}" ]]; then
    for candidate in "$HOME/.docker/sbx/bin/sbx" "$HOME/.local/bin/sbx"; do
        if [[ -x "$candidate" ]]; then
            exec "$candidate" "$@"
        fi
    done
fi

if executable="$(command -v sbx 2>/dev/null)" && [[ -x "$executable" ]]; then
    exec "$executable" "$@"
fi

printf '%s\n' \
    'sbx executable not found. Install Docker Sandboxes or set QUICKSHELL_SBX_EXECUTABLE.' >&2
exit 127
