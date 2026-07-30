#!/bin/bash

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
unset NEUROAPI_AGENTS_TEST_MODE
unset NEUROAPI_AGENTS_STATE_ROOT
unset NEUROAPI_AGENTS_CODEX_HOME
unset NEUROAPI_AGENTS_BIN_ROOT
unset NEUROAPI_AGENTS_SECURITY_BIN
/bin/bash "$SCRIPT_DIR/scripts/macos/install.sh"
NEUROAPI_EXIT_CODE=$?

printf '\nPress Return to close this window.'
IFS= read -r _
exit "$NEUROAPI_EXIT_CODE"
