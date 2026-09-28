#!/bin/bash
set -euo pipefail

KEYCHAIN_SERVICE='host.neuroapi.agents.api-key'
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
SERVICE_POINTER="$SCRIPT_DIR/../config/keychain-service"
if [[ -e "$SERVICE_POINTER" ]]; then
  IFS= read -r KEYCHAIN_SERVICE <"$SERVICE_POINTER"
  if [[ ! "$KEYCHAIN_SERVICE" =~ ^host\.neuroapi\.agents\.api-key\.[a-f0-9]{32}$ ]]; then
    printf 'Invalid NeuroAPI Keychain service pointer.\n' >&2
    exit 1
  fi
fi

if [[ "${NEUROAPI_AGENTS_TEST_MODE:-0}" == '1' ]] &&
  [[ -n "${NEUROAPI_AGENTS_SECURITY_BIN:-}" ]]; then
  SECURITY_BIN="$NEUROAPI_AGENTS_SECURITY_BIN"
else
  SECURITY_BIN='/usr/bin/security'
fi

CURRENT_USER="$(/usr/bin/id -un)"

exec "$SECURITY_BIN" find-generic-password \
  -a "$CURRENT_USER" \
  -s "$KEYCHAIN_SERVICE" \
  -w
