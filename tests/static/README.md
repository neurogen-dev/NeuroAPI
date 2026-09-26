# Static checks

`validate.ps1` enforces the public installer contract:

- required files exist;
- both Codex templates use `/v1/codex`, Responses and WebSocket with command-backed auth;
- setup wrappers do not accept or forward key arguments;
- Windows uses masked input and DPAPI;
- macOS delegates secret entry to Keychain `security -w`;
- tracked text contains no common real-secret shapes or remote-download-to-shell installer pattern.

Platform smoke tests use only the literal dummy value `test-neuroapi-token`.

`profile_contract.py` parses the TOML emitted by the isolated platform smoke tests.
It checks the exact endpoint, model, transport and helper arguments; credentials
must not appear in the profile. Both smoke tests also check reinstall stability.
The macOS test uses mock Keychain plus dedicated temporary paths without changing
`HOME` or `CODEX_HOME`. Windows DPAPI and launcher execution require Windows; a
PowerShell parser pass on another OS is not a Windows runtime smoke pass.

TOML validation requires Python 3.11+. For macOS machines whose `python3` is
older, use `NEUROAPI_AGENTS_TEST_PYTHON=/path/to/python3.12 /bin/bash tests/macos/smoke.sh`.
`windows-profile.ps1` renders the Windows profile template with synthetic paths
and parses it on any OS; it does not execute setup, helpers or DPAPI and does not
replace the native Windows smoke test.
