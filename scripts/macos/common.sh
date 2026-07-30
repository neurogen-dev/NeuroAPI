#!/bin/bash
set -euo pipefail

OWNER_MARKER_TEXT='neuroapi-agents:v1'
PROFILE_FILE_NAME='neuroapi-host.config.toml'
PROFILE_MARKER_FILE_NAME='.neuroapi-host.config.toml.neuroapi-agents-owned'
# shellcheck disable=SC2034 # Read by scripts that source this shared file.
KEYCHAIN_SERVICE='host.neuroapi.agents.api-key'
KEYCHAIN_MARKER_FILE_NAME='.keychain-item.neuroapi-agents-owned'

is_test_mode() {
  [[ "${NEUROAPI_AGENTS_TEST_MODE:-0}" == '1' ]]
}

state_root() {
  if is_test_mode && [[ -n "${NEUROAPI_AGENTS_STATE_ROOT:-}" ]]; then
    printf '%s\n' "$NEUROAPI_AGENTS_STATE_ROOT"
  else
    printf '%s\n' "$HOME/.local/share/neuroapi-agents"
  fi
}

codex_home() {
  if is_test_mode && [[ -n "${NEUROAPI_AGENTS_CODEX_HOME:-}" ]]; then
    printf '%s\n' "$NEUROAPI_AGENTS_CODEX_HOME"
  else
    printf '%s\n' "$HOME/.codex"
  fi
}

launcher_root() {
  if is_test_mode && [[ -n "${NEUROAPI_AGENTS_BIN_ROOT:-}" ]]; then
    printf '%s\n' "$NEUROAPI_AGENTS_BIN_ROOT"
  else
    printf '%s\n' "$HOME/.local/bin"
  fi
}

security_bin() {
  if is_test_mode && [[ -n "${NEUROAPI_AGENTS_SECURITY_BIN:-}" ]]; then
    printf '%s\n' "$NEUROAPI_AGENTS_SECURITY_BIN"
  else
    printf '%s\n' '/usr/bin/security'
  fi
}

current_user() {
  /usr/bin/id -un
}

state_marker_path() {
  printf '%s\n' "$(state_root)/.neuroapi-agents-owned"
}

keychain_marker_path() {
  printf '%s\n' "$(state_root)/$KEYCHAIN_MARKER_FILE_NAME"
}

profile_path() {
  printf '%s\n' "$(codex_home)/$PROFILE_FILE_NAME"
}

profile_marker_path() {
  printf '%s\n' "$(codex_home)/$PROFILE_MARKER_FILE_NAME"
}

launcher_marker_path() {
  printf '%s\n' "$(launcher_root)/.$1.neuroapi-agents-owned"
}

marker_is_owned() {
  local marker_path="$1"
  [[ -f "$marker_path" ]] && [[ "$(<"$marker_path")" == "$OWNER_MARKER_TEXT" ]]
}

write_marker() {
  printf '%s' "$OWNER_MARKER_TEXT" >"$1"
}

assert_state_root_owned_or_empty() {
  local root
  root="$(state_root)"
  if [[ ! -d "$root" ]]; then
    return
  fi
  if marker_is_owned "$(state_marker_path)"; then
    return
  fi
  if find "$root" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    printf 'Refusing to modify unowned directory: %s\n' "$root" >&2
    exit 1
  fi
}

assert_launcher_owned_or_missing() {
  local launcher_name="$1"
  local launcher_path
  local marker_path
  launcher_path="$(launcher_root)/$launcher_name"
  marker_path="$(launcher_marker_path "$launcher_name")"
  if [[ -e "$launcher_path" ]] && ! marker_is_owned "$marker_path"; then
    printf 'Refusing to overwrite unowned launcher: %s\n' "$launcher_path" >&2
    exit 1
  fi
}

toml_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}
