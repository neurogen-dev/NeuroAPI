# Static checks

`validate.ps1` enforces the public installer contract:

- required files exist;
- setup wrappers do not accept or forward key arguments;
- Windows uses masked input and DPAPI;
- macOS delegates secret entry to Keychain `security -w`;
- tracked text contains no common real-secret shapes or remote-download-to-shell installer pattern.

Platform smoke tests use only the literal dummy value `test-neuroapi-token`.
