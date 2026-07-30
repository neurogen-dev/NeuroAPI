#!/bin/bash
set -euo pipefail

KEYCHAIN_SERVICE='host.neuroapi.agents.api-key'

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
