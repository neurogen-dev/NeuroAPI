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
DESKTOP_CONFIG_ROOT="$(desktop_codex_home)"
DESKTOP_CONFIG_PATH="$DESKTOP_CONFIG_ROOT/config.toml"
DESKTOP_ORIGINAL_PATH="$STATE_ROOT/config/codex-desktop-original.toml"
DESKTOP_HASH_PATH="$STATE_ROOT/config/codex-desktop-state"
DESKTOP_CATALOG_PATH="$STATE_ROOT/config/codex-desktop-models.json"
LAUNCHER_ROOT="$(launcher_root)"
SECURITY_BIN="$(security_bin)"
CURRENT_USER="$(current_user)"
KEYCHAIN_ITEM_IS_OWNED=0
SERVICE_POINTER="$STATE_ROOT/config/keychain-service"
SERVICE_TO_DELETE="$KEYCHAIN_SERVICE"
if [[ -e "$SERVICE_POINTER" ]]; then
  IFS= read -r SERVICE_TO_DELETE <"$SERVICE_POINTER"
  if [[ ! "$SERVICE_TO_DELETE" =~ ^host\.neuroapi\.agents\.api-key\.[a-f0-9]{32}$ ]]; then
    printf 'Invalid NeuroAPI Keychain service pointer; refusing to remove it.\n' >&2
    exit 1
  fi
fi

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

# Do this before deleting the helper or Keychain secret: a changed Desktop
# config could still point at both and must remain usable for manual repair.
if [[ -L "$DESKTOP_ORIGINAL_PATH" || -L "$DESKTOP_HASH_PATH" || -L "$DESKTOP_CATALOG_PATH" ]]; then
  printf 'Codex Desktop ownership state uses a symlink; uninstall stopped without changing credentials.\n' >&2
  exit 1
fi
if [[ -e "$DESKTOP_HASH_PATH" ]]; then
  if [[ -L "$DESKTOP_CONFIG_ROOT" || -L "$DESKTOP_CONFIG_PATH" ]]; then
    printf 'Codex Desktop config uses a symlink; uninstall stopped without changing credentials.\n' >&2
    exit 1
  fi
  if [[ ! -f "$DESKTOP_ORIGINAL_PATH" || ! -f "$DESKTOP_CATALOG_PATH" || ! -f "$DESKTOP_CONFIG_PATH" ]]; then
    printf 'Codex Desktop ownership state is incomplete; uninstall stopped.\n' >&2
    exit 1
  fi
  IFS=' ' read -r desktop_state_version desktop_original_exists desktop_applied_hash desktop_original_hash <"$DESKTOP_HASH_PATH"
  if [[ "$desktop_state_version" == 'v1' ]]; then
    printf 'Codex Desktop backup predates integrity tracking. Re-run setup to upgrade it before uninstalling; credentials were kept.\n' >&2
    exit 1
  fi
  if [[ "$desktop_state_version" != 'v2' || ! "$desktop_original_exists" =~ ^[01]$ ||
    ! "$desktop_applied_hash" =~ ^[a-f0-9]{64}$ ||
    ! "$desktop_original_hash" =~ ^[a-f0-9]{64}$ ||
    "$(/usr/bin/shasum -a 256 "$DESKTOP_CONFIG_PATH" | /usr/bin/awk '{print $1}')" != "$desktop_applied_hash" ]]; then
    printf 'Codex Desktop config changed since setup. Restore the saved config manually or remove the NeuroAPI provider, then retry uninstall. Credentials were kept.\n' >&2
    exit 1
  fi
  if [[ "$(/usr/bin/shasum -a 256 "$DESKTOP_ORIGINAL_PATH" | /usr/bin/awk '{print $1}')" != "$desktop_original_hash" ]]; then
    printf 'Codex Desktop original backup changed since setup. Uninstall stopped; credentials were kept.\n' >&2
    exit 1
  fi
  if [[ "$desktop_original_exists" == '1' ]]; then
    cp -p -- "$DESKTOP_ORIGINAL_PATH" "$DESKTOP_CONFIG_PATH.new.$$"
    cmp -s -- "$DESKTOP_ORIGINAL_PATH" "$DESKTOP_CONFIG_PATH.new.$$"
    mv -f -- "$DESKTOP_CONFIG_PATH.new.$$" "$DESKTOP_CONFIG_PATH"
  else
    rm -f -- "$DESKTOP_CONFIG_PATH"
  fi
elif [[ -e "$DESKTOP_ORIGINAL_PATH" || -e "$DESKTOP_CATALOG_PATH" ]]; then
  printf 'Codex Desktop ownership state is incomplete; uninstall stopped.\n' >&2
  exit 1
elif [[ -f "$DESKTOP_CONFIG_PATH" ]] && /usr/bin/grep -Fq 'neuroapi_agents' "$DESKTOP_CONFIG_PATH"; then
  printf 'Codex Desktop still references NeuroAPI but its ownership state is missing. Uninstall stopped; credentials were kept.\n' >&2
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
    -s "$SERVICE_TO_DELETE" >/dev/null 2>&1; then
    printf 'No installer-owned NeuroAPI Keychain item was found, or it was already removed.\n'
  fi
else
  printf 'No installer-owned Keychain marker was found; any matching item was left in place.\n'
fi

printf 'Removed NeuroAPI installer-owned files and the Keychain item.\n'
printf 'The deleted key cannot be recovered from this installer.\n'
