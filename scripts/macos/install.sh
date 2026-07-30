#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=scripts/macos/common.sh
. "$SCRIPT_DIR/common.sh"

if [[ "$(uname -s)" != 'Darwin' ]] && ! is_test_mode; then
  printf 'This installer must run on macOS.\n' >&2
  exit 1
fi

assert_state_root_owned_or_empty
assert_launcher_owned_or_missing 'codex-neuroapi'
assert_launcher_owned_or_missing 'claude-neuroapi'

STATE_ROOT="$(state_root)"
CODEX_HOME="$(codex_home)"
LAUNCHER_ROOT="$(launcher_root)"
PROFILE_PATH="$(profile_path)"
PROFILE_MARKER_PATH="$(profile_marker_path)"
SECURITY_BIN="$(security_bin)"
CURRENT_USER="$(current_user)"
HELPER_PATH="$STATE_ROOT/bin/get-neuroapi-key.sh"
CLAUDE_SETTINGS_PATH="$STATE_ROOT/config/claude-settings.json"

if [[ -e "$PROFILE_PATH" ]] && ! marker_is_owned "$PROFILE_MARKER_PATH"; then
  printf 'Refusing to overwrite an unowned Codex profile: %s\n' "$PROFILE_PATH" >&2
  exit 1
fi

if "$SECURITY_BIN" find-generic-password \
  -a "$CURRENT_USER" \
  -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1 &&
  ! marker_is_owned "$(keychain_marker_path)"; then
  printf 'Refusing to overwrite an unowned Keychain item for service %s.\n' \
    "$KEYCHAIN_SERVICE" >&2
  exit 1
fi

mkdir -p "$STATE_ROOT/bin" "$STATE_ROOT/config" "$CODEX_HOME" "$LAUNCHER_ROOT"
write_marker "$(state_marker_path)"

if ! is_test_mode; then
  printf '\nNeuroAPI will ask macOS Keychain to store the API key for user %s.\n' \
    "$CURRENT_USER"
  printf 'Paste the key into the Keychain password prompt that follows.\n\n'
fi
"$SECURITY_BIN" add-generic-password \
  -U \
  -a "$CURRENT_USER" \
  -s "$KEYCHAIN_SERVICE" \
  -l 'NeuroAPI API key for local agents' \
  -j 'Used by the auditable NeuroAPI Codex CLI and Claude Code helpers' \
  -w
write_marker "$(keychain_marker_path)"

cp "$SCRIPT_DIR/get-neuroapi-key.sh" "$HELPER_PATH"
chmod 700 "$HELPER_PATH"

ESCAPED_HELPER_PATH="$(toml_escape "$HELPER_PATH")"
cat >"$PROFILE_PATH" <<EOF
# Managed by the NeuroAPI Agents installer.
model = "gpt-5.6-sol"
model_provider = "neuroapi"

[model_providers.neuroapi]
name = "NeuroAPI"
base_url = "https://neuroapi.host/v1"
wire_api = "responses"

[model_providers.neuroapi.auth]
command = "$ESCAPED_HELPER_PATH"
timeout_ms = 5000
refresh_interval_ms = 300000
EOF
write_marker "$PROFILE_MARKER_PATH"

rm -f -- "$CLAUDE_SETTINGS_PATH"
/usr/bin/plutil -create json "$CLAUDE_SETTINGS_PATH"
/usr/bin/plutil -insert '$schema' \
  -string 'https://json.schemastore.org/claude-code-settings.json' \
  "$CLAUDE_SETTINGS_PATH"
/usr/bin/plutil -insert apiKeyHelper -string "$HELPER_PATH" "$CLAUDE_SETTINGS_PATH"
/usr/bin/plutil -insert env -json '{}' "$CLAUDE_SETTINGS_PATH"
/usr/bin/plutil -insert env.ANTHROPIC_BASE_URL \
  -string 'https://neuroapi.host' \
  "$CLAUDE_SETTINGS_PATH"
/usr/bin/plutil -insert env.ANTHROPIC_MODEL \
  -string 'claude-sonnet-4-5' \
  "$CLAUDE_SETTINGS_PATH"
/usr/bin/plutil -lint "$CLAUDE_SETTINGS_PATH" >/dev/null

cat >"$LAUNCHER_ROOT/codex-neuroapi" <<'EOF'
#!/bin/bash
set -euo pipefail
exec codex --profile neuroapi-host "$@"
EOF

cat >"$LAUNCHER_ROOT/claude-neuroapi" <<EOF
#!/bin/bash
set -euo pipefail
exec claude --settings "$CLAUDE_SETTINGS_PATH" "\$@"
EOF

chmod 700 "$LAUNCHER_ROOT/codex-neuroapi" "$LAUNCHER_ROOT/claude-neuroapi"
write_marker "$(launcher_marker_path 'codex-neuroapi')"
write_marker "$(launcher_marker_path 'claude-neuroapi')"

printf '\nNeuroAPI setup is complete.\n'
printf 'Codex launcher:  %s/codex-neuroapi\n' "$LAUNCHER_ROOT"
printf 'Claude launcher: %s/claude-neuroapi\n' "$LAUNCHER_ROOT"
if [[ ":$PATH:" != *":$LAUNCHER_ROOT:"* ]]; then
  printf 'Your PATH does not include %s. Run the launchers by full path or add that directory yourself.\n' "$LAUNCHER_ROOT"
fi
if ! command -v codex >/dev/null 2>&1; then
  printf 'Warning: Codex CLI is not installed or is not on PATH.\n' >&2
fi
if ! command -v claude >/dev/null 2>&1; then
  printf 'Warning: Claude Code is not installed or is not on PATH.\n' >&2
fi
