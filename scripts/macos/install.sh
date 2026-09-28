#!/bin/bash
set +x
set -euo pipefail
umask 077

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
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
PROFILE_CONFIG_ROOT="$(codex_home)"
LAUNCHER_ROOT="$(launcher_root)"
PROFILE_PATH="$(profile_path)"
PROFILE_MARKER_PATH="$(profile_marker_path)"
SECURITY_BIN="$(security_bin)"
CURRENT_USER="$(current_user)"
HELPER_PATH="$STATE_ROOT/bin/get-neuroapi-key.sh"
CLAUDE_SETTINGS_PATH="$STATE_ROOT/config/claude-settings.json"
SERVICE_POINTER="$STATE_ROOT/config/keychain-service"
PREVIOUS_SERVICE="$KEYCHAIN_SERVICE"
if [[ -e "$SERVICE_POINTER" ]]; then
  IFS= read -r PREVIOUS_SERVICE <"$SERVICE_POINTER"
  if [[ ! "$PREVIOUS_SERVICE" =~ ^host\.neuroapi\.agents\.api-key\.[a-f0-9]{32}$ ]]; then
    printf 'Invalid existing NeuroAPI Keychain service pointer.\n' >&2
    exit 1
  fi
fi

if [[ -e "$PROFILE_PATH" ]] && ! marker_is_owned "$PROFILE_MARKER_PATH"; then
  printf 'Refusing to overwrite an unowned Codex profile: %s\n' "$PROFILE_PATH" >&2
  exit 1
fi

if "$SECURITY_BIN" find-generic-password \
  -a "$CURRENT_USER" \
  -s "$PREVIOUS_SERVICE" >/dev/null 2>&1 &&
  ! marker_is_owned "$(keychain_marker_path)"; then
  printf 'Refusing to overwrite an unowned Keychain item for service %s.\n' \
    "$PREVIOUS_SERVICE" >&2
  exit 1
fi

install_native_client() {
  local client="$1" url interpreter installer
  case "$client" in
    codex) url='https://chatgpt.com/codex/install.sh'; interpreter='/bin/sh' ;;
    claude) url='https://claude.ai/install.sh'; interpreter='/bin/bash' ;;
    *) return 1 ;;
  esac
  installer="$(mktemp "${TMPDIR:-/tmp}/neuroapi-${client}-install.XXXXXX")"
  if ! /usr/bin/curl --disable --fail --silent --show-error --location \
    --proto '=https' --proto-redir '=https' --max-redirs 3 \
    --connect-timeout 10 --max-time 60 --max-filesize 4194304 \
    --output "$installer" "$url"; then
    rm -f -- "$installer"
    printf 'Не удалось загрузить официальный установщик %s.\n' "$client" >&2
    return 1
  fi
  if ! "$interpreter" "$installer"; then
    rm -f -- "$installer"
    printf 'Установка %s завершилась с ошибкой.\n' "$client" >&2
    return 1
  fi
  rm -f -- "$installer"
}

if ! is_test_mode; then
  for client in codex claude; do
    case "$client" in
      codex) minimum=(0 158 0) ;;
      claude) minimum=(2 1 284) ;;
    esac
    client_bin="$(resolve_client_bin "$client" "${minimum[@]}" || true)"
    if [[ -n "$client_bin" ]] && client_version_at_least "$client_bin" "${minimum[@]}"; then
      continue
    fi
    printf 'Устанавливаю актуальный %s из официального источника.\n' "$client"
    install_native_client "$client"
    client_bin="$(resolve_client_bin "$client" "${minimum[@]}" || true)"
    if [[ -z "$client_bin" ]] || ! client_version_at_least "$client_bin" "${minimum[@]}"; then
      printf 'Не удалось найти совместимый %s после установки. Проверьте PATH и повторите настройку.\n' "$client" >&2
      exit 1
    fi
  done
fi

STAGE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/neuroapi-agents-stage.XXXXXX")"
CANDIDATE_SERVICE="${KEYCHAIN_SERVICE}.$(LC_ALL=C /usr/bin/od -An -N16 -tx1 /dev/urandom | /usr/bin/tr -d ' \n')"
CANDIDATE_OWNED=0
COMMIT_STARTED=0
STATE_ROOT_WAS_PRESENT=0
[[ -d "$STATE_ROOT" ]] && STATE_ROOT_WAS_PRESENT=1
PROMOTE_TARGETS=()
PROMOTE_BACKUPS=()
cleanup_stage() {
  local status=$? i
  trap - EXIT
  set +e
  if [[ "$status" -ne 0 && "$COMMIT_STARTED" == '1' ]]; then
    for ((i=${#PROMOTE_TARGETS[@]}-1; i>=0; i--)); do
      rm -f -- "${PROMOTE_TARGETS[i]}.new.$$"
      if [[ "${PROMOTE_BACKUPS[i]}" == 'present' ]]; then
        cp -p -- "$STAGE_ROOT/rollback/$i" "${PROMOTE_TARGETS[i]}"
      else
        rm -f -- "${PROMOTE_TARGETS[i]}"
      fi
    done
    if [[ "$STATE_ROOT_WAS_PRESENT" == '0' ]]; then
      rm -rf -- "$STATE_ROOT"
    elif ! marker_is_owned "$(state_marker_path)"; then
      rmdir -- "$STATE_ROOT/bin" "$STATE_ROOT/config" 2>/dev/null || true
    fi
  fi
  if [[ "$CANDIDATE_OWNED" == '1' ]]; then
    "$SECURITY_BIN" delete-generic-password -a "$CURRENT_USER" -s "$CANDIDATE_SERVICE" >/dev/null 2>&1 || true
  fi
  rm -rf -- "$STAGE_ROOT"
  exit "$status"
}
trap cleanup_stage EXIT
mkdir -p "$STAGE_ROOT/bin" "$STAGE_ROOT/config"
cp "$SCRIPT_DIR/get-neuroapi-key.sh" "$SCRIPT_DIR/launch-managed.sh" \
  "$SCRIPT_DIR/common.sh" "$SCRIPT_DIR/catalog-validator.js" "$STAGE_ROOT/bin/"
printf '%s\n' "$CANDIDATE_SERVICE" >"$STAGE_ROOT/config/keychain-service"
chmod 700 "$STAGE_ROOT/bin/get-neuroapi-key.sh" "$STAGE_ROOT/bin/launch-managed.sh"
chmod 600 "$STAGE_ROOT/bin/common.sh" "$STAGE_ROOT/bin/catalog-validator.js" \
  "$STAGE_ROOT/config/keychain-service"

if "$SECURITY_BIN" find-generic-password -a "$CURRENT_USER" -s "$CANDIDATE_SERVICE" >/dev/null 2>&1; then
  printf 'Keychain service collision; repeat setup.\n' >&2
  exit 1
fi

if ! is_test_mode; then
  printf '\nNeuroAPI will ask macOS Keychain to store the API key for user %s.\n' \
    "$CURRENT_USER"
  printf 'Paste the key into the Keychain password prompt that follows.\n\n'
fi
"$SECURITY_BIN" add-generic-password \
  -a "$CURRENT_USER" \
  -s "$CANDIDATE_SERVICE" \
  -l 'NeuroAPI API key for local agents' \
  -j 'Used by the auditable NeuroAPI Codex CLI and Claude Code helpers' \
  -w
CANDIDATE_OWNED=1

# Verify the candidate through the exact launcher logic before changing any
# working profile, helper, launcher, or previously stored Keychain item.
if ! is_test_mode || [[ "${NEUROAPI_AGENTS_TEST_PREFLIGHT:-0}" == '1' ]]; then
  for client in codex claude; do
    if ! "$STAGE_ROOT/bin/launch-managed.sh" "$client" --verify; then
      printf 'Проверка каталога %s не прошла. Существующие настройки и ключ сохранены.\n' "$client" >&2
      exit 1
    fi
  done
fi

ESCAPED_HELPER_PATH="$(toml_escape "$HELPER_PATH")"
cat >"$STAGE_ROOT/profile.toml" <<EOF
# Managed by the NeuroAPI Agents installer.
model_provider = "neuroapi"
web_search = "disabled"

# These Codex-hosted tools are not part of the NeuroAPI Responses contract.
[features]
multi_agent = false
goals = false
apps = false
browser_use = false

[model_providers.neuroapi]
name = "NeuroAPI"
base_url = "https://neuroapi.host/v1/codex"
wire_api = "responses"
supports_websockets = true

[model_providers.neuroapi.auth]
command = "$ESCAPED_HELPER_PATH"
timeout_ms = 5000
refresh_interval_ms = 300000
EOF
chmod 600 "$STAGE_ROOT/profile.toml"
STAGED_CLAUDE_SETTINGS="$STAGE_ROOT/config/claude-settings.json"
/usr/bin/plutil -create xml1 "$STAGED_CLAUDE_SETTINGS"
/usr/bin/plutil -insert "\$schema" \
  -string 'https://json.schemastore.org/claude-code-settings.json' \
  "$STAGED_CLAUDE_SETTINGS"
/usr/bin/plutil -insert apiKeyHelper -string "$HELPER_PATH" "$STAGED_CLAUDE_SETTINGS"
/usr/bin/plutil -insert env -dictionary "$STAGED_CLAUDE_SETTINGS"
/usr/bin/plutil -insert env.ANTHROPIC_BASE_URL \
  -string 'https://neuroapi.host/v1/claude-code' \
  "$STAGED_CLAUDE_SETTINGS"
/usr/bin/plutil -convert json "$STAGED_CLAUDE_SETTINGS"
chmod 600 "$STAGED_CLAUDE_SETTINGS"

mkdir -p "$STAGE_ROOT/launchers" "$STAGE_ROOT/rollback"
for client in codex claude; do
  {
    printf '#!/bin/bash\nset -euo pipefail\nexec /bin/bash '
    printf '%q ' "$STATE_ROOT/bin/launch-managed.sh" "$client"
    printf '"$@"\n'
  } >"$STAGE_ROOT/launchers/$client-neuroapi"
done
chmod 700 "$STAGE_ROOT/launchers/codex-neuroapi" "$STAGE_ROOT/launchers/claude-neuroapi"
write_marker "$STAGE_ROOT/state-marker"
write_marker "$STAGE_ROOT/profile-marker"
write_marker "$STAGE_ROOT/keychain-marker"
write_marker "$STAGE_ROOT/codex-launcher-marker"
write_marker "$STAGE_ROOT/claude-launcher-marker"

PROMOTE_TARGETS=(
  "$HELPER_PATH"
  "$STATE_ROOT/bin/launch-managed.sh"
  "$STATE_ROOT/bin/common.sh"
  "$STATE_ROOT/bin/catalog-validator.js"
  "$PROFILE_PATH"
  "$PROFILE_MARKER_PATH"
  "$CLAUDE_SETTINGS_PATH"
  "$LAUNCHER_ROOT/codex-neuroapi"
  "$LAUNCHER_ROOT/claude-neuroapi"
  "$(launcher_marker_path 'codex-neuroapi')"
  "$(launcher_marker_path 'claude-neuroapi')"
  "$(state_marker_path)"
  "$(keychain_marker_path)"
  "$SERVICE_POINTER"
)
PROMOTE_SOURCES=(
  "$STAGE_ROOT/bin/get-neuroapi-key.sh"
  "$STAGE_ROOT/bin/launch-managed.sh"
  "$STAGE_ROOT/bin/common.sh"
  "$STAGE_ROOT/bin/catalog-validator.js"
  "$STAGE_ROOT/profile.toml"
  "$STAGE_ROOT/profile-marker"
  "$STAGED_CLAUDE_SETTINGS"
  "$STAGE_ROOT/launchers/codex-neuroapi"
  "$STAGE_ROOT/launchers/claude-neuroapi"
  "$STAGE_ROOT/codex-launcher-marker"
  "$STAGE_ROOT/claude-launcher-marker"
  "$STAGE_ROOT/state-marker"
  "$STAGE_ROOT/keychain-marker"
  "$STAGE_ROOT/config/keychain-service"
)
for ((i=0; i<${#PROMOTE_TARGETS[@]}; i++)); do
  if [[ -L "${PROMOTE_TARGETS[i]}" ]]; then
    printf 'Refusing to replace a symlink: %s\n' "${PROMOTE_TARGETS[i]}" >&2
    exit 1
  fi
  if [[ -e "${PROMOTE_TARGETS[i]}" ]]; then
    cp -p -- "${PROMOTE_TARGETS[i]}" "$STAGE_ROOT/rollback/$i"
    PROMOTE_BACKUPS+=(present)
  else
    PROMOTE_BACKUPS+=(missing)
  fi
done

COMMIT_STARTED=1
mkdir -p "$STATE_ROOT/bin" "$STATE_ROOT/config" "$PROFILE_CONFIG_ROOT" "$LAUNCHER_ROOT"
for ((i=0; i<${#PROMOTE_TARGETS[@]}; i++)); do
  target="${PROMOTE_TARGETS[i]}"
  if is_test_mode && [[ "${NEUROAPI_AGENTS_TEST_FAIL_COMMIT_AT:-}" == "$(basename -- "$target")" ]]; then
    printf 'Simulated installer commit failure.\n' >&2
    exit 1
  fi
  cp -p -- "${PROMOTE_SOURCES[i]}" "$target.new.$$"
  mv -f -- "$target.new.$$" "$target"
done
CANDIDATE_OWNED=0
if [[ "$PREVIOUS_SERVICE" != "$CANDIDATE_SERVICE" ]] &&
  "$SECURITY_BIN" find-generic-password -a "$CURRENT_USER" -s "$PREVIOUS_SERVICE" >/dev/null 2>&1; then
  "$SECURITY_BIN" delete-generic-password -a "$CURRENT_USER" -s "$PREVIOUS_SERVICE" >/dev/null 2>&1 || true
fi

printf '\nNeuroAPI setup is complete.\n'
printf 'Codex launcher:  %s/codex-neuroapi\n' "$LAUNCHER_ROOT"
printf 'Claude launcher: %s/claude-neuroapi\n' "$LAUNCHER_ROOT"
if [[ ":$PATH:" != *":$LAUNCHER_ROOT:"* ]]; then
  printf 'Your PATH does not include %s. Run the launchers by full path or add that directory yourself.\n' "$LAUNCHER_ROOT"
fi
