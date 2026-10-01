#!/bin/bash
# Do not trace credentials even when the caller enabled shell tracing.
set +x
set -euo pipefail
umask 077

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=scripts/macos/common.sh
. "$SCRIPT_DIR/common.sh"
CLIENT="${1:-}"
shift || true
case "$CLIENT" in
  codex) MIN_MAJOR=0; MIN_MINOR=158; MIN_PATCH=0; ENDPOINT='https://codex.neuroapi.host/v1/models' ;;
  claude) MIN_MAJOR=2; MIN_MINOR=1; MIN_PATCH=284; ENDPOINT='https://claude.neuroapi.host/client-settings' ;;
  *) printf 'Неизвестный клиент NeuroAPI.\n' >&2; exit 1 ;;
esac

VERIFY_ONLY=0
DOCTOR=0
DOCTOR_GENERATE=0
EXPORT_CATALOG_ROOT=''
if [[ "${1:-}" == '--doctor' || "${1:-}" == '--doctor-generate' ]]; then
  DOCTOR=1
  [[ "$1" != '--doctor-generate' ]] || DOCTOR_GENERATE=1
  shift
  [[ $# == 0 ]] || { printf 'Диагностика не принимает дополнительные параметры.\n' >&2; exit 1; }
elif [[ "${1:-}" == --doctor* ]]; then
  printf 'Используйте --doctor или --doctor-generate.\n' >&2; exit 1
elif [[ "${1:-}" == '--verify' ]]; then
  VERIFY_ONLY=1
  shift
elif [[ "${1:-}" == '--export-codex-catalog' && "$CLIENT" == 'codex' && -n "${2:-}" ]]; then
  EXPORT_CATALOG_ROOT="$2"
  shift 2
fi

fail() { printf '%s\n' "$1" >&2; exit 1; }
if [[ "$CLIENT" == 'claude' ]]; then
  HOST_MANAGED="${CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST:-}"
  HOST_MANAGED="${HOST_MANAGED#"${HOST_MANAGED%%[![:space:]]*}"}"
  HOST_MANAGED="${HOST_MANAGED%"${HOST_MANAGED##*[![:space:]]}"}"
  case "$HOST_MANAGED" in
    1|[Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|[Oo][Nn])
      fail 'Провайдер Claude Code управляется приложением-хостом. Запустите NeuroAPI из самостоятельного терминала.' ;;
  esac
fi
if ! CLIENT_BIN="$(resolve_client_bin "$CLIENT" "$MIN_MAJOR" "$MIN_MINOR" "$MIN_PATCH")"; then
  fail "Не удалось проверить версию $CLIENT. Обновите клиент и повторите запуск."
fi
if ! client_version_at_least "$CLIENT_BIN" "$MIN_MAJOR" "$MIN_MINOR" "$MIN_PATCH"; then
  fail "Требуется $CLIENT версии $MIN_MAJOR.$MIN_MINOR.$MIN_PATCH или новее."
fi

if (( DOCTOR_GENERATE )); then
  printf 'Проверка выполнит один короткий платный API-запрос с вашего баланса; повторов не будет (до 180 секунд).\n'
fi

SNAPSHOT="$(mktemp -d "${TMPDIR:-/tmp}/neuroapi-models.XXXXXX")"
CHILD_PID=''
cleanup() { rm -rf -- "$SNAPSHOT"; }
stop_child() {
  local exit_status="$1"
  trap '' INT TERM HUP
  if [[ -n "$CHILD_PID" ]]; then
    kill -TERM "$CHILD_PID" 2>/dev/null || true
    wait "$CHILD_PID" 2>/dev/null || true
  fi
  exit "$exit_status"
}
launch_child() {
  local result=0
  "$@" <&0 &
  CHILD_PID=$!
  wait "$CHILD_PID" || result=$?
  CHILD_PID=''
  return "$result"
}
trap cleanup EXIT
trap 'stop_child 130' INT
trap 'stop_child 143' TERM
trap 'stop_child 129' HUP

CURL_BIN='/usr/bin/curl'
if [[ "${NEUROAPI_AGENTS_TEST_MODE:-0}" == '1' && -n "${NEUROAPI_AGENTS_CURL_BIN:-}" ]]; then
  CURL_BIN="$NEUROAPI_AGENTS_CURL_BIN"
fi
# The credential stays in shell memory and anonymous pipes. Never export it,
# include it in argv, or put it in a curl config file.
if ! credential="$("$SCRIPT_DIR/get-neuroapi-key.sh" 2>/dev/null)"; then
  fail 'Не удалось получить ключ NeuroAPI из Keychain.'
fi
if [[ ${#credential} -gt 4096 || ! "$credential" =~ ^[A-Za-z0-9._~-]+$ ]]; then
  unset credential
  fail 'Ключ NeuroAPI имеет неподдерживаемый формат. Повторите настройку.'
fi
CATALOG_HEADERS=(--header 'Accept: application/json')
if [[ "$CLIENT" == 'claude' ]]; then
  CATALOG_HEADERS+=(--header 'X-NeuroAPI-Client-Settings-Version: 2')
fi
if ! printf 'header = "Authorization: Bearer %s"\n' "$credential" |
  "$CURL_BIN" --disable --config - --silent --fail --proto '=https' \
    --proto-redir '=https' --max-redirs 0 --connect-timeout 5 --max-time 20 \
    --max-filesize 4194304 "${CATALOG_HEADERS[@]}" \
    --write-out '\n%{http_code}' "$ENDPOINT" 2>/dev/null |
  /usr/bin/osascript -l JavaScript "$SCRIPT_DIR/catalog-validator.js" \
    "$CLIENT" "$SNAPSHOT" "$SCRIPT_DIR/get-neuroapi-key.sh" \
    3< <(printf '%s' "$credential") >/dev/null 2>/dev/null; then
  unset credential
  fail 'Не удалось загрузить актуальные модели NeuroAPI. Проверьте доступ ключа и соединение; старый список не используется.'
fi
if (( DOCTOR )); then
  IFS= read -r DEFAULT_MODEL <"$SNAPSHOT/model.txt"
  printf 'Клиент %s: версия совместима. Ключ: скрыт; доступ к актуальному каталогу подтверждён.\n' "$CLIENT"
  printf 'Адрес каталога: %s\nМодель по умолчанию: %s\n' "$ENDPOINT" "$DEFAULT_MODEL"
  if (( DOCTOR_GENERATE )); then
    if [[ "$CLIENT" == 'codex' ]]; then
      GENERATION_ENDPOINT='https://codex.neuroapi.host/v1/responses'
      printf '{"model":"%s","input":"Reply with NEUROAPI_OK only.","store":false,"max_output_tokens":256,"reasoning":{"effort":"low"}}' "$DEFAULT_MODEL" >"$SNAPSHOT/request.json"
    else
      GENERATION_ENDPOINT='https://claude.neuroapi.host/v1/messages'
      printf '{"model":"%s","messages":[{"role":"user","content":"Reply with NEUROAPI_OK only."}],"max_tokens":64}' "$DEFAULT_MODEL" >"$SNAPSHOT/request.json"
    fi
    START_SECONDS=$SECONDS
    if ! printf 'header = "Authorization: Bearer %s"\n' "$credential" |
      "$CURL_BIN" --disable --config - --silent --fail --proto '=https' \
        --max-redirs 0 --connect-timeout 5 --max-time 180 --max-filesize 4194304 \
        --header 'Content-Type: application/json' --header 'anthropic-version: 2023-06-01' \
        --request POST --data-binary "@$SNAPSHOT/request.json" --write-out '\n%{http_code}' "$GENERATION_ENDPOINT" 2>/dev/null |
      /usr/bin/osascript -l JavaScript "$SCRIPT_DIR/catalog-validator.js" \
        "doctor-$CLIENT" "$SNAPSHOT" "$SCRIPT_DIR/get-neuroapi-key.sh" \
        3< <(printf '%s' "$credential") 2>/dev/null; then
      unset credential
      if [[ -f "$SNAPSHOT/doctor-error.txt" ]]; then
        fail 'Идентификатор модели не подтверждён (model_identity_unverified). Возможно сопоставление имени; проверьте настройки модели.'
      fi
      fail 'Генерация не подтверждена. Проверьте баланс и доступность модели; повтор автоматически не выполняется.'
    fi
    printf 'Время API-запроса: %s секунд.\n' "$((SECONDS - START_SECONDS))"
  else
    printf 'Генерация не выполнялась. Для платной проверки ответа используйте --doctor-generate.\n'
  fi
  unset credential
  exit 0
fi
unset credential

if [[ -n "$EXPORT_CATALOG_ROOT" ]]; then
  cp -- "$SNAPSHOT/models.json" "$EXPORT_CATALOG_ROOT/models.json"
  cp -- "$SNAPSHOT/model.txt" "$EXPORT_CATALOG_ROOT/model.txt"
  exit 0
fi

if (( VERIFY_ONLY )); then
  printf 'Каталог %s проверен.\n' "$CLIENT"
  exit 0
fi

if [[ "$CLIENT" == 'codex' ]]; then
  IFS= read -r DEFAULT_MODEL <"$SNAPSHOT/model.txt"
  CATALOG_PATH="$SNAPSHOT/models.json"
  CATALOG_PATH="${CATALOG_PATH//\\/\\\\}"
  CATALOG_PATH="${CATALOG_PATH//\"/\\\"}"
  # User arguments follow generated defaults intentionally, so explicit --model
  # and ordinary CLI overrides retain their documented meaning.
  launch_child "$CLIENT_BIN" --profile neuroapi-host -c "model_catalog_json=\"$CATALOG_PATH\"" -c "model=\"$DEFAULT_MODEL\"" "$@"
else
  run_claude() {
    # Remove inherited selectors and credentials only in this child. The
    # fetched settings and local helper must use the same scoped key.
    for variable in $(compgen -e); do
      case "$variable" in
        ANTHROPIC_MODEL|ANTHROPIC_DEFAULT_*|ANTHROPIC_SMALL_FAST_*|CLAUDE_CODE_SUBAGENT_MODEL|ANTHROPIC_AUTH_TOKEN|ANTHROPIC_API_KEY|ANTHROPIC_BASE_URL|ANTHROPIC_CUSTOM_HEADERS|CLAUDE_CODE_OAUTH_TOKEN|CLAUDE_CODE_USE_BEDROCK|CLAUDE_CODE_USE_VERTEX|CLAUDE_CODE_USE_FOUNDRY|CLAUDE_CODE_USE_ANTHROPIC_AWS|CLAUDE_CODE_USE_MANTLE)
          unset "$variable" ;;
      esac
    done
    exec "$CLIENT_BIN" --settings "$SNAPSHOT/settings.json" "$@"
  }
  launch_child run_claude "$@"
fi
