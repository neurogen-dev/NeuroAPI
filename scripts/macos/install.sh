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
DESKTOP_CONFIG_ROOT="$(desktop_codex_home)"
DESKTOP_CONFIG_PATH="$DESKTOP_CONFIG_ROOT/config.toml"
DESKTOP_ORIGINAL_PATH="$STATE_ROOT/config/codex-desktop-original.toml"
DESKTOP_HASH_PATH="$STATE_ROOT/config/codex-desktop-state"
DESKTOP_CATALOG_PATH="$STATE_ROOT/config/codex-desktop-models.json"
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

DESKTOP_OPT_IN=0
if [[ -L "$DESKTOP_ORIGINAL_PATH" || -L "$DESKTOP_HASH_PATH" || -L "$DESKTOP_CATALOG_PATH" ]]; then
  printf 'Refusing to use symlinked Codex Desktop ownership state.\n' >&2
  exit 1
fi
if [[ -e "$DESKTOP_HASH_PATH" ]]; then
  if [[ ! -f "$DESKTOP_ORIGINAL_PATH" || ! -f "$DESKTOP_CATALOG_PATH" || ! -f "$DESKTOP_CONFIG_PATH" ]]; then
    printf 'Codex Desktop ownership state is incomplete. Existing settings were not changed.\n' >&2
    exit 1
  fi
  IFS=' ' read -r desktop_state_version desktop_original_exists desktop_applied_hash desktop_original_hash <"$DESKTOP_HASH_PATH"
  if [[ ! "$desktop_state_version" =~ ^v[12]$ || ! "$desktop_original_exists" =~ ^[01]$ ||
    ! "$desktop_applied_hash" =~ ^[a-f0-9]{64}$ ||
    "$(/usr/bin/shasum -a 256 "$DESKTOP_CONFIG_PATH" | /usr/bin/awk '{print $1}')" != "$desktop_applied_hash" ]]; then
    printf 'Codex Desktop config changed since setup. Resolve it manually before reinstalling.\n' >&2
    exit 1
  fi
  if [[ "$desktop_state_version" == 'v2' ]] &&
    { [[ ! "$desktop_original_hash" =~ ^[a-f0-9]{64}$ ]] ||
      [[ "$(/usr/bin/shasum -a 256 "$DESKTOP_ORIGINAL_PATH" | /usr/bin/awk '{print $1}')" != "$desktop_original_hash" ]]; }; then
    printf 'Codex Desktop original backup changed since setup. Settings and credentials were kept.\n' >&2
    exit 1
  fi
  DESKTOP_OPT_IN=1
elif [[ -e "$DESKTOP_ORIGINAL_PATH" || -e "$DESKTOP_CATALOG_PATH" ]]; then
  printf 'Codex Desktop ownership state is incomplete. Existing settings were not changed.\n' >&2
  exit 1
elif is_test_mode; then
  [[ "${NEUROAPI_AGENTS_TEST_DESKTOP_OPT_IN:-0}" == '1' ]] && DESKTOP_OPT_IN=1
else
  printf '\nПодключить также Codex Desktop к NeuroAPI? [y/N]: '
  IFS= read -r desktop_answer || desktop_answer=''
  case "$desktop_answer" in [yY]|[yY][eE][sS]|[дД]|[дД][аА]) DESKTOP_OPT_IN=1 ;; esac
fi
if [[ "$DESKTOP_OPT_IN" == '1' && ( -L "$DESKTOP_CONFIG_ROOT" || -L "$DESKTOP_CONFIG_PATH" ) ]]; then
  printf 'Refusing to use a symlinked Codex Desktop configuration path.\n' >&2
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
PROMOTE_COUNT=0
STATE_ROOT_WAS_PRESENT=0
[[ -d "$STATE_ROOT" ]] && STATE_ROOT_WAS_PRESENT=1
DESKTOP_ROOT_WAS_PRESENT=0
[[ -d "$DESKTOP_CONFIG_ROOT" ]] && DESKTOP_ROOT_WAS_PRESENT=1
PROMOTE_TARGETS=()
PROMOTE_BACKUPS=()
cleanup_stage() {
  local status=$? i rollback_failed=0 restore_tmp
  trap - EXIT
  set +e
  if [[ "$status" -ne 0 && "$COMMIT_STARTED" == '1' ]]; then
    for ((i=0; i<${#PROMOTE_TARGETS[@]}; i++)); do
      rm -f -- "${PROMOTE_TARGETS[i]}.new.$$" || rollback_failed=1
    done
    for ((i=PROMOTE_COUNT-1; i>=0; i--)); do
      # A user or another process may have edited a promoted file. Leave that
      # state intact and keep both credentials plus all snapshots for recovery.
      if ! cmp -s -- "${PROMOTE_SOURCES[i]}" "${PROMOTE_TARGETS[i]}"; then
        rollback_failed=1
        continue
      fi
      if is_test_mode && [[ "${NEUROAPI_AGENTS_TEST_FAIL_ROLLBACK_AT:-}" == "$(basename -- "${PROMOTE_TARGETS[i]}")" ]]; then
        rollback_failed=1
        continue
      fi
      if [[ "${PROMOTE_BACKUPS[i]}" == 'present' ]]; then
        restore_tmp="${PROMOTE_TARGETS[i]}.rollback.$$"
        if ! cp -p -- "$STAGE_ROOT/rollback/$i" "$restore_tmp" ||
          ! cmp -s -- "$STAGE_ROOT/rollback/$i" "$restore_tmp" ||
          ! mv -f -- "$restore_tmp" "${PROMOTE_TARGETS[i]}" ||
          ! cmp -s -- "$STAGE_ROOT/rollback/$i" "${PROMOTE_TARGETS[i]}"; then
          rollback_failed=1
          rm -f -- "$restore_tmp" || true
        fi
      else
        if ! rm -f -- "${PROMOTE_TARGETS[i]}" ||
          [[ -e "${PROMOTE_TARGETS[i]}" || -L "${PROMOTE_TARGETS[i]}" ]]; then
          rollback_failed=1
        fi
      fi
    done
    if [[ "$rollback_failed" == '0' ]]; then
      if [[ "$STATE_ROOT_WAS_PRESENT" == '0' ]]; then
        rm -rf -- "$STATE_ROOT" || rollback_failed=1
      elif ! marker_is_owned "$(state_marker_path)"; then
        rmdir -- "$STATE_ROOT/bin" "$STATE_ROOT/config" 2>/dev/null || true
      fi
      if [[ "$DESKTOP_OPT_IN" == '1' && "$DESKTOP_ROOT_WAS_PRESENT" == '0' ]]; then
        rmdir -- "$DESKTOP_CONFIG_ROOT" 2>/dev/null || true
      fi
    fi
    if [[ "$rollback_failed" == '1' ]]; then
      printf 'NeuroAPI setup rollback is incomplete. Snapshots and the candidate Keychain credential were kept. Recovery files: %s\n' "$STAGE_ROOT" >&2
      exit "$status"
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

if [[ "$DESKTOP_OPT_IN" == '1' ]]; then
  mkdir -p "$STAGE_ROOT/desktop"
  if [[ -e "$DESKTOP_HASH_PATH" ]]; then
    cp -p -- "$DESKTOP_ORIGINAL_PATH" "$STAGE_ROOT/desktop/original.toml"
  elif [[ -e "$DESKTOP_CONFIG_PATH" ]]; then
    [[ -f "$DESKTOP_CONFIG_PATH" ]] || { printf 'Invalid Codex Desktop config.\n' >&2; exit 1; }
    cp -p -- "$DESKTOP_CONFIG_PATH" "$STAGE_ROOT/desktop/original.toml"
  else
    : >"$STAGE_ROOT/desktop/original.toml"
  fi
  chmod 600 "$STAGE_ROOT/desktop/original.toml"
  desktop_expected_exists=0
  desktop_expected_hash=''
  if [[ -e "$DESKTOP_CONFIG_PATH" ]]; then
    desktop_expected_exists=1
    desktop_expected_hash="$(/usr/bin/shasum -a 256 "$DESKTOP_CONFIG_PATH" | /usr/bin/awk '{print $1}')"
  fi
  if [[ -e "$DESKTOP_HASH_PATH" && "$desktop_expected_hash" != "$desktop_applied_hash" ]]; then
    printf 'Codex Desktop config changed during setup; existing settings were preserved.\n' >&2
    exit 1
  fi
  if [[ -e "$DESKTOP_HASH_PATH" && "$desktop_state_version" == 'v2' &&
    "$(/usr/bin/shasum -a 256 "$STAGE_ROOT/desktop/original.toml" | /usr/bin/awk '{print $1}')" != "$desktop_original_hash" ]]; then
    printf 'Codex Desktop original backup changed during setup; existing settings were preserved.\n' >&2
    exit 1
  fi
  if ! "$STAGE_ROOT/bin/launch-managed.sh" codex --export-codex-catalog "$STAGE_ROOT/desktop"; then
    printf 'Не удалось проверить модели Codex Desktop для этого ключа. Настройки сохранены.\n' >&2
    exit 1
  fi
  /usr/bin/osascript -l JavaScript "$SCRIPT_DIR/desktop-config.js" \
    "$STAGE_ROOT/desktop/original.toml" "$STAGE_ROOT/desktop/model.txt" \
    "$DESKTOP_CATALOG_PATH" "$HELPER_PATH" "$STAGE_ROOT/desktop/config.toml"
  chmod 600 "$STAGE_ROOT/desktop/config.toml" "$STAGE_ROOT/desktop/models.json"
  desktop_original_exists=0
  [[ -e "$DESKTOP_CONFIG_PATH" && ! -e "$DESKTOP_HASH_PATH" ]] && desktop_original_exists=1
  if [[ -e "$DESKTOP_HASH_PATH" ]]; then
    IFS=' ' read -r _ desktop_original_exists _ <"$DESKTOP_HASH_PATH"
  fi
  desktop_hash="$(/usr/bin/shasum -a 256 "$STAGE_ROOT/desktop/config.toml" | /usr/bin/awk '{print $1}')"
  desktop_original_hash="$(/usr/bin/shasum -a 256 "$STAGE_ROOT/desktop/original.toml" | /usr/bin/awk '{print $1}')"
  printf 'v2 %s %s %s\n' "$desktop_original_exists" "$desktop_hash" "$desktop_original_hash" >"$STAGE_ROOT/desktop/state"
  desktop_codex_bin="$(resolve_client_bin codex 0 158 0 || true)"
  if [[ -z "$desktop_codex_bin" ]] || ! client_version_at_least "$desktop_codex_bin" 0 158 0; then
    printf 'Для проверки Codex Desktop требуется Codex CLI 0.158.0 или новее.\n' >&2
    exit 1
  fi
  mkdir -p "$STAGE_ROOT/desktop/validate"
  /usr/bin/osascript -l JavaScript "$SCRIPT_DIR/desktop-config.js" \
    "$STAGE_ROOT/desktop/original.toml" "$STAGE_ROOT/desktop/model.txt" \
    "$STAGE_ROOT/desktop/models.json" "$STAGE_ROOT/bin/get-neuroapi-key.sh" \
    "$STAGE_ROOT/desktop/validate/config.toml"
  if ! CODEX_HOME="$STAGE_ROOT/desktop/validate" "$desktop_codex_bin" features list >/dev/null; then
    printf 'Codex отклонил настройки Desktop. Существующий конфиг сохранён.\n' >&2
    exit 1
  fi
fi

ESCAPED_HELPER_PATH="$(toml_escape "$HELPER_PATH")"
cat >"$STAGE_ROOT/profile.toml" <<EOF
# Managed by the NeuroAPI Agents installer.
model_provider = "neuroapi"
web_search = "live"

# API-key CLI startup avoids plugin catalog sync; standalone MCP stays available.
[features]
plugins = false
remote_plugin = false
multi_agent = false
goals = false
apps = false
browser_use = false

[model_providers.neuroapi]
name = "NeuroAPI"
base_url = "https://codex.neuroapi.host/v1"
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
  -string 'https://claude.neuroapi.host' \
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
if [[ "$DESKTOP_OPT_IN" == '1' ]]; then
  # Save the preimage and scoped model catalog before exposing the new config.
  PROMOTE_TARGETS+=("$DESKTOP_ORIGINAL_PATH" "$DESKTOP_CATALOG_PATH" "$DESKTOP_HASH_PATH" "$DESKTOP_CONFIG_PATH")
  PROMOTE_SOURCES+=("$STAGE_ROOT/desktop/original.toml" "$STAGE_ROOT/desktop/models.json" \
    "$STAGE_ROOT/desktop/state" "$STAGE_ROOT/desktop/config.toml")
fi
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
if [[ "$DESKTOP_OPT_IN" == '1' ]]; then
  mkdir -p "$DESKTOP_CONFIG_ROOT"
fi
for ((i=0; i<${#PROMOTE_TARGETS[@]}; i++)); do
  target="${PROMOTE_TARGETS[i]}"
  if [[ "$DESKTOP_OPT_IN" == '1' && "$target" == "$DESKTOP_CONFIG_PATH" ]]; then
    if [[ "$desktop_expected_exists" == '1' ]]; then
      if [[ ! -f "$target" || -L "$target" ||
        "$(/usr/bin/shasum -a 256 "$target" | /usr/bin/awk '{print $1}')" != "$desktop_expected_hash" ]]; then
        printf 'Codex Desktop config changed during setup; existing settings were preserved.\n' >&2
        exit 1
      fi
    elif [[ -e "$target" || -L "$target" ]]; then
      printf 'Codex Desktop config appeared during setup; existing settings were preserved.\n' >&2
      exit 1
    fi
  fi
  if is_test_mode && [[ "${NEUROAPI_AGENTS_TEST_FAIL_COMMIT_AT:-}" == "$(basename -- "$target")" ]]; then
    printf 'Simulated installer commit failure.\n' >&2
    exit 1
  fi
  cp -p -- "${PROMOTE_SOURCES[i]}" "$target.new.$$"
  mv -f -- "$target.new.$$" "$target"
  PROMOTE_COUNT=$((i + 1))
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
