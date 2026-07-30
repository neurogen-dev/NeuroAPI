#!/bin/bash
set -euo pipefail

REPO_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/neuroapi-agents-test.XXXXXX")"
MOCK_SECURITY="$TMP_ROOT/security"
SECURITY_LOG="$TMP_ROOT/security.log"
MOCK_KEYCHAIN_STATE="$TMP_ROOT/keychain-present"

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
case "$1" in
  add-generic-password)
    [[ "${!#}" == '-w' ]] || {
      printf 'Expected -w to be the final argument.\n' >&2
      exit 1
    }
    : >"$NEUROAPI_AGENTS_MOCK_KEYCHAIN_STATE"
    ;;
  find-generic-password)
    [[ -f "$NEUROAPI_AGENTS_MOCK_KEYCHAIN_STATE" ]] || exit 44
    if [[ "${!#}" == '-w' ]]; then
      printf 'test-neuroapi-token\n'
    fi
    ;;
  delete-generic-password)
    rm -f -- "$NEUROAPI_AGENTS_MOCK_KEYCHAIN_STATE"
    ;;
  *)
    printf 'Unexpected security command: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
chmod 700 "$MOCK_SECURITY"

export HOME="$TMP_ROOT/home"
export USER='neuroapi-test'
export NEUROAPI_AGENTS_TEST_MODE=1
export NEUROAPI_AGENTS_STATE_ROOT="$TMP_ROOT/state"
export NEUROAPI_AGENTS_CODEX_HOME="$TMP_ROOT/codex"
export NEUROAPI_AGENTS_BIN_ROOT="$TMP_ROOT/bin"
export NEUROAPI_AGENTS_SECURITY_BIN="$MOCK_SECURITY"
export NEUROAPI_AGENTS_SECURITY_LOG="$SECURITY_LOG"
export NEUROAPI_AGENTS_MOCK_KEYCHAIN_STATE="$MOCK_KEYCHAIN_STATE"
mkdir -p "$HOME" "$NEUROAPI_AGENTS_CODEX_HOME"
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

python3 -c 'import json,pathlib,sys; json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))' \
  "$NEUROAPI_AGENTS_STATE_ROOT/config/claude-settings.json"
python3 -c 'import pathlib,sys,tomllib; tomllib.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))' \
  "$NEUROAPI_AGENTS_CODEX_HOME/neuroapi-host.config.toml"
/bin/bash "$REPO_ROOT/scripts/macos/install.sh" >/dev/null 2>/dev/null
/bin/bash "$REPO_ROOT/scripts/macos/uninstall.sh" >/dev/null

[[ ! -e "$NEUROAPI_AGENTS_STATE_ROOT" ]]
[[ ! -e "$NEUROAPI_AGENTS_CODEX_HOME/neuroapi-host.config.toml" ]]
[[ -e "$NEUROAPI_AGENTS_CODEX_HOME/user-owned.txt" ]]
[[ ! -e "$NEUROAPI_AGENTS_BIN_ROOT/codex-neuroapi" ]]
[[ ! -e "$NEUROAPI_AGENTS_BIN_ROOT/claude-neuroapi" ]]
grep -Fq 'delete-generic-password' "$SECURITY_LOG"

printf 'pre-existing-secret\n' >"$MOCK_KEYCHAIN_STATE"
delete_count_before="$(grep -c 'delete-generic-password' "$SECURITY_LOG")"
NEUROAPI_AGENTS_STATE_ROOT="$TMP_ROOT/no-installer-state" \
  /bin/bash "$REPO_ROOT/scripts/macos/uninstall.sh" >/dev/null
delete_count_after="$(grep -c 'delete-generic-password' "$SECURITY_LOG")"
[[ "$delete_count_after" == "$delete_count_before" ]]
[[ -f "$MOCK_KEYCHAIN_STATE" ]]

UNOWNED_KEYCHAIN_STATE="$TMP_ROOT/unowned-keychain-state"
if NEUROAPI_AGENTS_STATE_ROOT="$UNOWNED_KEYCHAIN_STATE" \
  /bin/bash "$REPO_ROOT/scripts/macos/install.sh" >/dev/null 2>/dev/null; then
  printf 'Setup overwrote an unowned Keychain item.\n' >&2
  exit 1
fi
[[ -f "$MOCK_KEYCHAIN_STATE" ]]

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
