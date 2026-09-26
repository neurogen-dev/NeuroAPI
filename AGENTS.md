# NeuroAPI Agents repository guidance

- This branch is the public, auditable installer for NeuroAPI integrations with Codex CLI and Claude Code.
- Never accept API keys through command-line arguments, persist them as plaintext, or print them outside the dedicated credential helpers.
- Windows secrets must stay DPAPI-protected for the current user. macOS secrets must stay in the current user's login Keychain.
- Do not overwrite unrelated Codex, Claude Code, shell, or PATH configuration. Update and uninstall only files marked as installer-owned.
- Keep Windows PowerShell 5.1 compatibility and macOS system Bash compatibility.
- Validate script syntax, generated TOML/JSON, idempotency, secret handling, and uninstall boundaries before publishing.

- Codex uses the user-level profile-v2 file and `/v1/codex` with WebSocket enabled. Publish installers only after authenticated server catalog and HTTP/WebSocket release checks; HTTP fallback keeps the same profile URL.
- Managed launchers fetch and validate fresh key-scoped catalogs into private per-launch snapshots; never fall back to stale/bundled lists or accept executable server settings. Claude's explicit base URL is `/v1/claude-code`. Keep ordinary keys, preserve unrelated configuration, and document managed-policy/explicit-override boundaries.
