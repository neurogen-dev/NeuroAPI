#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=scripts/macos/common.sh
. "$SCRIPT_DIR/common.sh"

if [[ "$(uname -s)" != 'Darwin' ]] && ! is_test_mode; then
  printf 'This uninstaller must run on macOS.\n' >&2
  exit 1
fi

STATE_ROOT="$(state_root)"
PROFILE_PATH="$(profile_path)"
PROFILE_MARKER_PATH="$(profile_marker_path)"
LAUNCHER_ROOT="$(launcher_root)"
SECURITY_BIN="$(security_bin)"
CURRENT_USER="$(current_user)"
KEYCHAIN_ITEM_IS_OWNED=0

if ! is_test_mode; then
  printf 'This removes the NeuroAPI launchers and the API key from macOS Keychain.\n'
  printf 'Type DELETE to continue: '
  IFS= read -r confirmation
  if [[ "$confirmation" != 'DELETE' ]]; then
    printf 'Uninstall cancelled. Nothing was removed.\n'
    exit 0
  fi
fi

if [[ -d "$STATE_ROOT" ]] && ! marker_is_owned "$(state_marker_path)"; then
  printf 'Refusing to remove an unowned directory: %s\n' "$STATE_ROOT" >&2
  exit 1
fi

if marker_is_owned "$(keychain_marker_path)"; then
  KEYCHAIN_ITEM_IS_OWNED=1
fi

if [[ -e "$PROFILE_PATH" ]]; then
  if marker_is_owned "$PROFILE_MARKER_PATH"; then
    rm -f -- "$PROFILE_PATH" "$PROFILE_MARKER_PATH"
  else
    printf 'Leaving unowned Codex profile in place: %s\n' "$PROFILE_PATH" >&2
  fi
elif [[ -e "$PROFILE_MARKER_PATH" ]]; then
  rm -f -- "$PROFILE_MARKER_PATH"
fi

for launcher_name in codex-neuroapi claude-neuroapi; do
  launcher_path="$LAUNCHER_ROOT/$launcher_name"
  marker_path="$(launcher_marker_path "$launcher_name")"
  if [[ -e "$launcher_path" ]]; then
    if marker_is_owned "$marker_path"; then
      rm -f -- "$launcher_path" "$marker_path"
    else
      printf 'Leaving unowned launcher in place: %s\n' "$launcher_path" >&2
    fi
  elif [[ -e "$marker_path" ]]; then
    rm -f -- "$marker_path"
  fi
done

if [[ -d "$STATE_ROOT" ]]; then
  rm -rf -- "$STATE_ROOT"
fi

if [[ "$KEYCHAIN_ITEM_IS_OWNED" == '1' ]]; then
  if ! "$SECURITY_BIN" delete-generic-password \
    -a "$CURRENT_USER" \
    -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1; then
    printf 'No installer-owned NeuroAPI Keychain item was found, or it was already removed.\n'
  fi
else
  printf 'No installer-owned Keychain marker was found; any matching item was left in place.\n'
fi

printf 'Removed NeuroAPI installer-owned files and the Keychain item.\n'
printf 'The deleted key cannot be recovered from this installer.\n'
