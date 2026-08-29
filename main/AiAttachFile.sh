#!/usr/bin/env bash
set -u

report_failure() {
  qs -c main ipc call ai attachmentFailed "$1" >/dev/null 2>&1 || true
}

report_cancelled() {
  qs -c main ipc call ai attachmentCancelled >/dev/null 2>&1 || true
}

if [[ $# -lt 1 ]]; then
  exit 2
fi

mode="$1"
runtime_root="${XDG_RUNTIME_DIR:-}"
if [[ -z "$runtime_root" ]]; then
  report_failure 'XDG_RUNTIME_DIR is unavailable'
  exit 1
fi
if ! command -v file >/dev/null 2>&1; then
  report_failure 'file is unavailable; install the official Arch file package'
  exit 1
fi

attachment_directory="$runtime_root/quickshell-ai"
umask 077
if ! mkdir -p "$attachment_directory" || ! chmod 700 "$attachment_directory"; then
  report_failure 'Could not create the private attachment directory'
  exit 1
fi

source_path=""
clipboard_type=""
attachment_kind="image"
display_name="Pasted image"
mime_encoding="binary"

case "$mode" in
  picker)
    if ! command -v zenity >/dev/null 2>&1; then
      report_failure 'zenity is unavailable; install the zenity package'
      exit 1
    fi
    if ! source_path="$(zenity --file-selection --title='Attach a file' \
        --file-filter='Images and text files | *')"; then
      report_cancelled
      exit 0
    fi
    if [[ -z "$source_path" || ! -f "$source_path" || -L "$source_path" ]]; then
      report_failure 'The selected attachment is not a regular file'
      exit 1
    fi
    display_name="${source_path##*/}"
    display_name="${display_name//$'\n'/ }"
    display_name="${display_name//$'\r'/ }"
    display_name="${display_name//$'\t'/ }"
    display_name="${display_name:0:120}"
    mime_type="$(file --brief --mime-type --no-dereference -- "$source_path")"
    mime_encoding="$(file --brief --mime-encoding --no-dereference -- "$source_path")"
    ;;
  clipboard)
    if ! command -v wl-paste >/dev/null 2>&1; then
      report_failure 'wl-paste is unavailable; install the wl-clipboard package'
      exit 1
    fi
    while IFS= read -r offered_type; do
      case "$offered_type" in
        image/png)
          clipboard_type='image/png'
          break
          ;;
        image/jpeg|image/webp)
          if [[ -z "$clipboard_type" ]]; then
            clipboard_type="$offered_type"
          fi
          ;;
      esac
    done < <(wl-paste --list-types 2>/dev/null)
    if [[ -z "$clipboard_type" ]]; then
      report_cancelled
      exit 0
    fi
    mime_type="$clipboard_type"
    ;;
  *)
    exit 2
    ;;
esac

case "$mime_type" in
  image/png) extension='png' ;;
  image/jpeg) extension='jpg' ;;
  image/webp) extension='webp' ;;
  *)
    if [[ "$mime_type" != 'application/x-empty' && "$mime_encoding" == 'binary' ]]; then
      report_failure 'Only PNG, JPEG, WebP, and text files can be attached'
      exit 1
    fi
    attachment_kind='text'
    extension='txt'
    ;;
esac

if ! attachment_path="$(mktemp --tmpdir="$attachment_directory" "attachment-XXXXXXXXXXXX.$extension")"; then
  report_failure 'Could not allocate a private attachment file'
  exit 1
fi

if [[ "$mode" == 'picker' ]]; then
  if ! cp --reflink=auto -- "$source_path" "$attachment_path"; then
    rm -f -- "$attachment_path"
    report_failure 'Could not copy the selected file'
    exit 1
  fi
elif ! wl-paste --type "$clipboard_type" >"$attachment_path"; then
  rm -f -- "$attachment_path"
  report_failure 'Could not read the clipboard image'
  exit 1
fi

actual_mime="$(file --brief --mime-type --no-dereference -- "$attachment_path")"
actual_encoding="$(file --brief --mime-encoding --no-dereference -- "$attachment_path")"
if [[ "$attachment_kind" == 'image' && "$actual_mime" != "$mime_type" ]] \
    || [[ "$attachment_kind" == 'text' && "$actual_mime" != 'application/x-empty' \
      && "$actual_encoding" == 'binary' ]]; then
  rm -f -- "$attachment_path"
  report_failure 'The attachment format could not be verified'
  exit 1
fi

if ! qs -c main ipc call ai attachImportedFile \
    "$attachment_path" "$attachment_kind" "$display_name" >/dev/null 2>&1; then
  rm -f -- "$attachment_path"
  exit 1
fi
