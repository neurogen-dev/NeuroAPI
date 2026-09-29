#!/bin/bash
set -euo pipefail

REPO_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
PYTHON_BIN="${NEUROAPI_AGENTS_TEST_PYTHON:-python3}"
"$PYTHON_BIN" -c 'import tomllib'
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/neuroapi-agents-test.XXXXXX")"
# Resolve synthetic values through the same pure helper used by setup/uninstall.
# shellcheck source=scripts/macos/common.sh
. "$REPO_ROOT/scripts/macos/common.sh"
[[ "$(resolve_codex_config_root '/tmp/custom profile' '/tmp/user')" == '/tmp/custom profile' ]]
[[ "$(resolve_codex_config_root '' '/tmp/user')" == '/tmp/user/.codex' ]]
MOCK_SECURITY="$TMP_ROOT/security"
SECURITY_LOG="$TMP_ROOT/security.log"
MOCK_KEYCHAIN_STATE="$TMP_ROOT/keychain"

cleanup() {
  rm -rf -- "$TMP_ROOT"
}

report_error() {
  local status="$1"
  local line="$2"
  printf 'macOS smoke failed at line %s with status %s.\n' "$line" "$status" >&2
  if [[ -f "$TMP_ROOT/install.err" ]]; then
    printf '%s\n' '--- installer stderr ---' >&2
    tail -n 160 "$TMP_ROOT/install.err" >&2
  fi
  if [[ -f "$SECURITY_LOG" ]]; then
    printf '%s\n' '--- mock Keychain calls ---' >&2
    sed -n '1,120p' "$SECURITY_LOG" >&2
  fi
}

trap 'report_error "$?" "$LINENO"' ERR
trap cleanup EXIT

cat >"$MOCK_SECURITY" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >>"$NEUROAPI_AGENTS_SECURITY_LOG"
service=''
for ((i=1; i<=$#; i++)); do
  if [[ "${!i}" == '-s' ]]; then
    j=$((i+1))
    service="${!j}"
    break
  fi
done
[[ "$service" =~ ^host\.neuroapi\.agents\.api-key(\.[a-f0-9]{32})?$ ]] || exit 1
mkdir -p -- "$NEUROAPI_AGENTS_MOCK_KEYCHAIN_STATE"
item="$NEUROAPI_AGENTS_MOCK_KEYCHAIN_STATE/$service"
case "$1" in
  add-generic-password)
    [[ "${!#}" == '-w' ]] || {
      printf 'Expected -w to be the final argument.\n' >&2
      exit 1
    }
    [[ ! -e "$item" ]] || exit 1
    printf '%s\n' "${NEUROAPI_AGENTS_MOCK_NEXT_TOKEN:-test-neuroapi-token}" >"$item"
    ;;
  find-generic-password)
    [[ -f "$item" ]] || exit 44
    if [[ "${!#}" == '-w' ]]; then
      cat -- "$item"
    fi
    ;;
  delete-generic-password)
    rm -f -- "$item"
    ;;
  *)
    printf 'Unexpected security command: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
chmod 700 "$MOCK_SECURITY"

export NEUROAPI_AGENTS_TEST_MODE=1
export NEUROAPI_AGENTS_STATE_ROOT="$TMP_ROOT/state"
export NEUROAPI_AGENTS_CODEX_HOME="$TMP_ROOT/codex"
export NEUROAPI_AGENTS_BIN_ROOT="$TMP_ROOT/bin"
export NEUROAPI_AGENTS_SECURITY_BIN="$MOCK_SECURITY"
export NEUROAPI_AGENTS_SECURITY_LOG="$SECURITY_LOG"
export NEUROAPI_AGENTS_MOCK_KEYCHAIN_STATE="$MOCK_KEYCHAIN_STATE"
mkdir -p "$NEUROAPI_AGENTS_CODEX_HOME"
printf 'keep\n' >"$NEUROAPI_AGENTS_CODEX_HOME/user-owned.txt"

/bin/bash -x "$REPO_ROOT/scripts/macos/install.sh" \
  >"$TMP_ROOT/install.out" 2>"$TMP_ROOT/install.err"

grep -Fq 'add-generic-password' "$SECURITY_LOG"
grep -Fq -- '-w' "$SECURITY_LOG"
if grep -Fq 'test-neuroapi-token' "$TMP_ROOT/install.out"; then
  printf 'Installer stdout exposed the dummy token.\n' >&2
  exit 1
fi
if grep -Fq 'test-neuroapi-token' "$TMP_ROOT/install.err"; then
  printf 'Installer stderr exposed the dummy token.\n' >&2
  exit 1
fi
[[ -f "$NEUROAPI_AGENTS_CODEX_HOME/neuroapi-host.config.toml" ]]
[[ -f "$NEUROAPI_AGENTS_STATE_ROOT/config/claude-settings.json" ]]
[[ -x "$NEUROAPI_AGENTS_STATE_ROOT/bin/get-neuroapi-key.sh" ]]
[[ -x "$NEUROAPI_AGENTS_BIN_ROOT/codex-neuroapi" ]]
[[ -x "$NEUROAPI_AGENTS_BIN_ROOT/claude-neuroapi" ]]

helper_output="$("$NEUROAPI_AGENTS_STATE_ROOT/bin/get-neuroapi-key.sh")"
[[ "$helper_output" == 'test-neuroapi-token' ]]

"$PYTHON_BIN" -c 'import json,pathlib,sys; json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))' \
  "$NEUROAPI_AGENTS_STATE_ROOT/config/claude-settings.json"
"$PYTHON_BIN" "$REPO_ROOT/tests/static/profile_contract.py" \
  "$NEUROAPI_AGENTS_CODEX_HOME/neuroapi-host.config.toml" macos \
  "$NEUROAPI_AGENTS_STATE_ROOT/bin/get-neuroapi-key.sh"
if grep -R -Fq 'test-neuroapi-token' "$NEUROAPI_AGENTS_CODEX_HOME" "$NEUROAPI_AGENTS_STATE_ROOT" "$NEUROAPI_AGENTS_BIN_ROOT"; then
  printf 'Generated configuration or launchers exposed the dummy token.\n' >&2
  exit 1
fi
"$PYTHON_BIN" "$REPO_ROOT/tests/macos/catalog_smoke.py" "$NEUROAPI_AGENTS_STATE_ROOT" "$NEUROAPI_AGENTS_BIN_ROOT"

cp "$NEUROAPI_AGENTS_CODEX_HOME/neuroapi-host.config.toml" "$TMP_ROOT/profile-before.toml"
/bin/bash "$REPO_ROOT/scripts/macos/install.sh" >/dev/null 2>/dev/null
cmp "$TMP_ROOT/profile-before.toml" "$NEUROAPI_AGENTS_CODEX_HOME/neuroapi-host.config.toml"

# A failed authenticated preflight must leave the previous working key and
# launcher configuration untouched. A successful retry changes only the key.
MOCK_CLIENT_BIN="$TMP_ROOT/mock-client-bin"
mkdir -p "$MOCK_CLIENT_BIN"
cat >"$MOCK_CLIENT_BIN/codex" <<'EOF'
#!/bin/bash
if [[ "$1" == '--version' ]]; then
  printf '%s\n' "${MOCK_CODEX_VERSION:-codex-cli 0.158.0}"
elif [[ "$1 $2" == 'features list' ]]; then
  "${NEUROAPI_AGENTS_TEST_PYTHON:-python3}" -c 'import pathlib,sys,tomllib; tomllib.loads((pathlib.Path(sys.argv[1]) / "config.toml").read_text())' "$CODEX_HOME"
else
  exit 1
fi
EOF
cat >"$MOCK_CLIENT_BIN/claude" <<'EOF'
#!/bin/bash
[[ "$1" == '--version' ]] || exit 1
printf '2.1.284 (Claude Code)\n'
EOF
chmod 700 "$MOCK_CLIENT_BIN/codex" "$MOCK_CLIENT_BIN/claude"
if MOCK_CODEX_VERSION='codex-cli 0.158.0-alpha' \
  client_version_at_least "$MOCK_CLIENT_BIN/codex" 0 158 0; then
  printf 'Prerelease Codex version was accepted.\n' >&2
  exit 1
fi
MOCK_CURL="$TMP_ROOT/mock-curl"
cat >"$MOCK_CURL" <<'EOF'
#!/bin/bash
set -euo pipefail
config="$(cat)"
[[ "$config" == *'Bearer '* ]] || exit 1
[[ "$config" != *'bad-rotation'* ]] || exit 22
case "${!#}" in
  https://neuroapi.host/v1/codex/models) cat "$NEUROAPI_TEST_CODEX_CATALOG" ;;
  https://neuroapi.host/v1/claude-code/client-settings) cat "$NEUROAPI_TEST_CLAUDE_CATALOG" ;;
  *) exit 1 ;;
esac
printf '\n200'
EOF
chmod 700 "$MOCK_CURL"
export NEUROAPI_TEST_CODEX_CATALOG="$TMP_ROOT/codex-catalog.json"
export NEUROAPI_TEST_CLAUDE_CATALOG="$TMP_ROOT/claude-catalog.json"
"$PYTHON_BIN" - "$NEUROAPI_TEST_CODEX_CATALOG" "$NEUROAPI_TEST_CLAUDE_CATALOG" <<'PY'
import json, pathlib, sys
model = dict(slug='gpt-6-sol', display_name='GPT-6 Sol', description='Test model',
             supported_reasoning_levels=[], shell_type='shell_command', visibility='list',
             supported_in_api=True, priority=0, base_instructions='test',
             model_messages={'instructions_template': 'test'},
             supports_reasoning_summary_parameter=False, support_verbosity=False,
             supports_parallel_tool_calls=False, truncation_policy={'mode': 'tokens', 'limit': 100},
             context_window=10000, max_context_window=10000, auto_compact_token_limit=8000,
             effective_context_window_percent=90, experimental_supported_tools=[],
             input_modalities=['text'], supports_search_tool=False, use_responses_lite=False,
             input_token_limit=8000, output_token_limit=2000)
pathlib.Path(sys.argv[1]).write_text(json.dumps({'models': [model], 'default_model': model['slug']}))
pathlib.Path(sys.argv[2]).write_text(json.dumps({
    'model': 'claude-opus-5-5', 'availableModels': ['claude-opus-5-5'],
    'enforceAvailableModels': True, 'fallbackModel': [],
    'modelPicker': {'options': [{'model': 'claude-opus-5-5', 'label': 'Opus'}],
                    'replaceBuiltInOptions': True},
    'env': {'ANTHROPIC_DEFAULT_OPUS_MODEL': 'claude-opus-5-5'}}))
PY
export NEUROAPI_AGENTS_TEST_PREFLIGHT=1
export NEUROAPI_AGENTS_CURL_BIN="$MOCK_CURL"
rotation_path="$NEUROAPI_AGENTS_STATE_ROOT/config/keychain-service"
old_service="$(<"$rotation_path")"
cp "$rotation_path" "$TMP_ROOT/pointer-before"
cp "$NEUROAPI_AGENTS_STATE_ROOT/config/claude-settings.json" "$TMP_ROOT/claude-before.json"
cp "$NEUROAPI_AGENTS_BIN_ROOT/codex-neuroapi" "$TMP_ROOT/codex-before"
if PATH="$MOCK_CLIENT_BIN:$PATH" NEUROAPI_AGENTS_MOCK_NEXT_TOKEN=bad-rotation \
  /bin/bash "$REPO_ROOT/scripts/macos/install.sh" >"$TMP_ROOT/rotation.out" 2>"$TMP_ROOT/rotation.err"; then
  printf 'Invalid replacement key passed preflight.\n' >&2
  exit 1
fi
cmp "$TMP_ROOT/pointer-before" "$rotation_path"
cmp "$TMP_ROOT/profile-before.toml" "$NEUROAPI_AGENTS_CODEX_HOME/neuroapi-host.config.toml"
cmp "$TMP_ROOT/claude-before.json" "$NEUROAPI_AGENTS_STATE_ROOT/config/claude-settings.json"
cmp "$TMP_ROOT/codex-before" "$NEUROAPI_AGENTS_BIN_ROOT/codex-neuroapi"
[[ "$("$NEUROAPI_AGENTS_STATE_ROOT/bin/get-neuroapi-key.sh")" == 'test-neuroapi-token' ]]
[[ -f "$MOCK_KEYCHAIN_STATE/$old_service" ]]
[[ "$(find "$MOCK_KEYCHAIN_STATE" -type f | wc -l | tr -d ' ')" == '1' ]]
if grep -R -Fq 'bad-rotation' "$NEUROAPI_AGENTS_STATE_ROOT" "$NEUROAPI_AGENTS_CODEX_HOME" "$TMP_ROOT/rotation.out" "$TMP_ROOT/rotation.err"; then
  printf 'Rejected replacement key leaked.\n' >&2
  exit 1
fi
for failure_point in claude-settings.json keychain-service; do
  if PATH="$MOCK_CLIENT_BIN:$PATH" NEUROAPI_AGENTS_MOCK_NEXT_TOKEN=good-rotation \
    NEUROAPI_AGENTS_TEST_FAIL_COMMIT_AT="$failure_point" \
    /bin/bash "$REPO_ROOT/scripts/macos/install.sh" >"$TMP_ROOT/rotation.out" 2>"$TMP_ROOT/rotation.err"; then
    printf 'Injected installer failure at %s was ignored.\n' "$failure_point" >&2
    exit 1
  fi
  cmp "$TMP_ROOT/pointer-before" "$rotation_path"
  cmp "$TMP_ROOT/profile-before.toml" "$NEUROAPI_AGENTS_CODEX_HOME/neuroapi-host.config.toml"
  cmp "$TMP_ROOT/claude-before.json" "$NEUROAPI_AGENTS_STATE_ROOT/config/claude-settings.json"
  cmp "$TMP_ROOT/codex-before" "$NEUROAPI_AGENTS_BIN_ROOT/codex-neuroapi"
  [[ "$("$NEUROAPI_AGENTS_STATE_ROOT/bin/get-neuroapi-key.sh")" == 'test-neuroapi-token' ]]
  [[ -f "$MOCK_KEYCHAIN_STATE/$old_service" ]]
  [[ "$(find "$MOCK_KEYCHAIN_STATE" -type f | wc -l | tr -d ' ')" == '1' ]]
done
PATH="$MOCK_CLIENT_BIN:$PATH" NEUROAPI_AGENTS_MOCK_NEXT_TOKEN=good-rotation \
  /bin/bash "$REPO_ROOT/scripts/macos/install.sh" >"$TMP_ROOT/rotation.out" 2>"$TMP_ROOT/rotation.err"
[[ "$("$NEUROAPI_AGENTS_STATE_ROOT/bin/get-neuroapi-key.sh")" == 'good-rotation' ]]
[[ "$(<"$rotation_path")" != "$old_service" ]]
[[ ! -e "$MOCK_KEYCHAIN_STATE/$old_service" ]]
cmp "$TMP_ROOT/profile-before.toml" "$NEUROAPI_AGENTS_CODEX_HOME/neuroapi-host.config.toml"
if grep -R -Fq 'good-rotation' "$NEUROAPI_AGENTS_STATE_ROOT" "$NEUROAPI_AGENTS_CODEX_HOME" "$TMP_ROOT/rotation.out" "$TMP_ROOT/rotation.err"; then
  printf 'Replacement key leaked.\n' >&2
  exit 1
fi

# Desktop opt-in uses the real user-level config, independent of the CLI
# profile. Existing TOML must survive byte-for-byte after guarded uninstall.
export NEUROAPI_AGENTS_DESKTOP_CODEX_HOME="$TMP_ROOT/desktop-codex"
export NEUROAPI_AGENTS_TEST_DESKTOP_OPT_IN=1
mkdir -p "$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME"
cat >"$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME/config.toml" <<'EOF'
# personal Codex settings
model = "gpt-6-astra"

[features]
apps = false
EOF
cp "$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME/config.toml" "$TMP_ROOT/desktop-original.toml"
if PATH="$MOCK_CLIENT_BIN:$PATH" NEUROAPI_AGENTS_TEST_FAIL_COMMIT_AT=config.toml \
  /bin/bash "$REPO_ROOT/scripts/macos/install.sh" >"$TMP_ROOT/desktop.out" 2>"$TMP_ROOT/desktop.err"; then
  printf 'Injected Desktop commit failure was ignored.\n' >&2
  exit 1
fi
cmp "$TMP_ROOT/desktop-original.toml" "$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME/config.toml"
[[ ! -e "$NEUROAPI_AGENTS_STATE_ROOT/config/codex-desktop-state" ]]
PATH="$MOCK_CLIENT_BIN:$PATH" /bin/bash "$REPO_ROOT/scripts/macos/install.sh" \
  >"$TMP_ROOT/desktop.out" 2>"$TMP_ROOT/desktop.err"
desktop_config="$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME/config.toml"
desktop_catalog="$NEUROAPI_AGENTS_STATE_ROOT/config/codex-desktop-models.json"
grep -Fq 'model_provider = "neuroapi_agents"' "$desktop_config"
grep -Fq 'base_url = "https://codex.neuroapi.host/v1"' "$desktop_config"
grep -Fq 'supports_websockets = false' "$desktop_config"
grep -Fq 'model = "gpt-6-sol"' "$desktop_config"
[[ -f "$desktop_catalog" ]]
"$PYTHON_BIN" -c 'import json,pathlib,sys,tomllib; cfg=tomllib.loads(pathlib.Path(sys.argv[1]).read_text()); catalog=json.loads(pathlib.Path(sys.argv[2]).read_text()); assert cfg["model"]==catalog["models"][0]["slug"]' "$desktop_config" "$desktop_catalog"
if grep -R -Fq 'good-rotation' "$desktop_config" "$desktop_catalog"; then
  printf 'Desktop configuration exposed the dummy token.\n' >&2
  exit 1
fi
cp "$desktop_config" "$TMP_ROOT/desktop-installed.toml"
PATH="$MOCK_CLIENT_BIN:$PATH" /bin/bash "$REPO_ROOT/scripts/macos/install.sh" \
  >"$TMP_ROOT/desktop.out" 2>"$TMP_ROOT/desktop.err"
cmp "$TMP_ROOT/desktop-installed.toml" "$desktop_config"
printf '\n# user changed this later\n' >>"$desktop_config"
if /bin/bash "$REPO_ROOT/scripts/macos/uninstall.sh" >"$TMP_ROOT/desktop.out" 2>"$TMP_ROOT/desktop.err"; then
  printf 'Uninstall deleted credentials for a modified Desktop config.\n' >&2
  exit 1
fi
[[ -f "$NEUROAPI_AGENTS_STATE_ROOT/bin/get-neuroapi-key.sh" ]]
[[ "$("$NEUROAPI_AGENTS_STATE_ROOT/bin/get-neuroapi-key.sh")" == 'good-rotation' ]]
cp "$TMP_ROOT/desktop-installed.toml" "$desktop_config"
unset NEUROAPI_AGENTS_TEST_DESKTOP_OPT_IN
unset NEUROAPI_AGENTS_TEST_PREFLIGHT NEUROAPI_AGENTS_CURL_BIN
/bin/bash "$REPO_ROOT/scripts/macos/uninstall.sh" >/dev/null

[[ ! -e "$NEUROAPI_AGENTS_STATE_ROOT" ]]
cmp "$TMP_ROOT/desktop-original.toml" "$desktop_config"
[[ ! -e "$NEUROAPI_AGENTS_CODEX_HOME/neuroapi-host.config.toml" ]]
[[ -e "$NEUROAPI_AGENTS_CODEX_HOME/user-owned.txt" ]]
[[ ! -e "$NEUROAPI_AGENTS_BIN_ROOT/codex-neuroapi" ]]
[[ ! -e "$NEUROAPI_AGENTS_BIN_ROOT/claude-neuroapi" ]]
grep -Fq 'delete-generic-password' "$SECURITY_LOG"

# Fresh Desktop config, reserved provider name, malformed TOML, and symlink
# refusal are tested independently of the existing-config flow above.
export NEUROAPI_AGENTS_DESKTOP_CODEX_HOME="$TMP_ROOT/desktop-fresh"
export NEUROAPI_AGENTS_TEST_DESKTOP_OPT_IN=1
export NEUROAPI_AGENTS_CURL_BIN="$MOCK_CURL"
mkdir -p "$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME"
cat >"$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME/config.toml" <<'EOF'
[model_providers.neuroapi_agents]
name = "user owned"
EOF
cp "$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME/config.toml" "$TMP_ROOT/desktop-conflict.toml"
if PATH="$MOCK_CLIENT_BIN:$PATH" /bin/bash "$REPO_ROOT/scripts/macos/install.sh" >/dev/null 2>/dev/null; then
  printf 'Setup overwrote a user-owned Desktop provider.\n' >&2
  exit 1
fi
cmp "$TMP_ROOT/desktop-conflict.toml" "$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME/config.toml"
printf 'broken = [\n' >"$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME/config.toml"
if PATH="$MOCK_CLIENT_BIN:$PATH" /bin/bash "$REPO_ROOT/scripts/macos/install.sh" >/dev/null 2>/dev/null; then
  printf 'Setup accepted malformed Desktop TOML.\n' >&2
  exit 1
fi
[[ "$(<"$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME/config.toml")" == 'broken = [' ]]
mv "$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME/config.toml" "$TMP_ROOT/malformed-desktop.toml"
ln -s "$TMP_ROOT/malformed-desktop.toml" "$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME/config.toml"
if PATH="$MOCK_CLIENT_BIN:$PATH" /bin/bash "$REPO_ROOT/scripts/macos/install.sh" >/dev/null 2>/dev/null; then
  printf 'Setup accepted a symlinked Desktop config.\n' >&2
  exit 1
fi
[[ "$(<"$TMP_ROOT/malformed-desktop.toml")" == 'broken = [' ]]
unlink "$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME/config.toml"
PATH="$MOCK_CLIENT_BIN:$PATH" /bin/bash "$REPO_ROOT/scripts/macos/install.sh" >/dev/null 2>"$TMP_ROOT/install.err"
[[ -f "$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME/config.toml" ]]
grep -Fq 'model = "gpt-6-sol"' "$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME/config.toml"
/bin/bash "$REPO_ROOT/scripts/macos/uninstall.sh" >/dev/null
[[ ! -e "$NEUROAPI_AGENTS_DESKTOP_CODEX_HOME/config.toml" ]]
unset NEUROAPI_AGENTS_TEST_DESKTOP_OPT_IN NEUROAPI_AGENTS_CURL_BIN

printf 'pre-existing-secret\n' >"$MOCK_KEYCHAIN_STATE/host.neuroapi.agents.api-key"
delete_count_before="$(grep -c 'delete-generic-password' "$SECURITY_LOG")"
NEUROAPI_AGENTS_STATE_ROOT="$TMP_ROOT/no-installer-state" \
  /bin/bash "$REPO_ROOT/scripts/macos/uninstall.sh" >/dev/null
delete_count_after="$(grep -c 'delete-generic-password' "$SECURITY_LOG")"
[[ "$delete_count_after" == "$delete_count_before" ]]
[[ -f "$MOCK_KEYCHAIN_STATE/host.neuroapi.agents.api-key" ]]

UNOWNED_KEYCHAIN_STATE="$TMP_ROOT/unowned-keychain-state"
if NEUROAPI_AGENTS_STATE_ROOT="$UNOWNED_KEYCHAIN_STATE" \
  /bin/bash "$REPO_ROOT/scripts/macos/install.sh" >/dev/null 2>/dev/null; then
  printf 'Setup overwrote an unowned Keychain item.\n' >&2
  exit 1
fi
[[ -f "$MOCK_KEYCHAIN_STATE/host.neuroapi.agents.api-key" ]]

UNOWNED_STATE="$TMP_ROOT/unowned-state"
mkdir -p "$UNOWNED_STATE"
printf 'keep\n' >"$UNOWNED_STATE/user-owned.txt"
if NEUROAPI_AGENTS_STATE_ROOT="$UNOWNED_STATE" \
  /bin/bash "$REPO_ROOT/scripts/macos/install.sh" >/dev/null 2>/dev/null; then
  printf 'Setup accepted an unowned non-empty state directory.\n' >&2
  exit 1
fi
grep -Fq 'keep' "$UNOWNED_STATE/user-owned.txt"

UNOWNED_PROFILE_STATE="$TMP_ROOT/unowned-profile-state"
printf '# user-owned profile\n' >"$NEUROAPI_AGENTS_CODEX_HOME/neuroapi-host.config.toml"
if NEUROAPI_AGENTS_STATE_ROOT="$UNOWNED_PROFILE_STATE" \
  /bin/bash "$REPO_ROOT/scripts/macos/install.sh" >/dev/null 2>/dev/null; then
  printf 'Setup accepted an unowned Codex profile.\n' >&2
  exit 1
fi
grep -Fq 'user-owned profile' "$NEUROAPI_AGENTS_CODEX_HOME/neuroapi-host.config.toml"

printf 'macOS installer smoke test passed.\n'
