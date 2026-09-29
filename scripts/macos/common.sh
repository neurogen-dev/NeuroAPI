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

resolve_codex_config_root() {
  local configured_root="$1"
  local user_root="$2"
  if [[ -n "$configured_root" ]]; then
    printf '%s\n' "$configured_root"
  else
    printf '%s\n' "$user_root/.codex"
  fi
}

codex_home() {
  if is_test_mode && [[ -n "${NEUROAPI_AGENTS_CODEX_HOME:-}" ]]; then
    printf '%s\n' "$NEUROAPI_AGENTS_CODEX_HOME"
  else
    resolve_codex_config_root "${CODEX_HOME:-}" "$HOME"
  fi
}

desktop_codex_home() {
  if is_test_mode && [[ -n "${NEUROAPI_AGENTS_DESKTOP_CODEX_HOME:-}" ]]; then
    printf '%s\n' "$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME"
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

resolve_client_bin() {
  local client="$1"
  shift
  local resolved native
  resolved="$(command -v "$client" 2>/dev/null || true)"
  native="$HOME/.local/bin/$client"
  if (( $# == 3 )); then
    if [[ -n "$resolved" && -x "$resolved" ]] && client_version_at_least "$resolved" "$@"; then
      printf '%s\n' "$resolved"
      return 0
    fi
    if [[ -x "$native" ]] && client_version_at_least "$native" "$@"; then
      printf '%s\n' "$native"
      return 0
    fi
  fi
  if [[ -n "$resolved" && -x "$resolved" ]]; then
    printf '%s\n' "$resolved"
    return 0
  fi
  # Native Codex and Claude installers use ~/.local/bin; GUI-launched
  # terminals do not always inherit that directory in PATH immediately.
  if [[ -x "$native" ]]; then
    printf '%s\n' "$native"
    return 0
  fi
  return 1
}

client_version_at_least() {
  local binary="$1" minimum_major="$2" minimum_minor="$3" minimum_patch="$4"
  local version major minor patch suffix
  version="$("$binary" --version 2>/dev/null)" || return 1
  [[ "$version" =~ (^|[[:space:]])([0-9]+)\.([0-9]+)\.([0-9]+)([^[:space:]]*) ]] || return 1
  suffix="${BASH_REMATCH[5]}"
  [[ -z "$suffix" ]] || return 1
  major=$((10#${BASH_REMATCH[2]}))
  minor=$((10#${BASH_REMATCH[3]}))
  patch=$((10#${BASH_REMATCH[4]}))
  (( major > minimum_major ||
    (major == minimum_major && minor > minimum_minor) ||
    (major == minimum_major && minor == minimum_minor && patch >= minimum_patch) ))
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
