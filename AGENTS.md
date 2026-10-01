# NeuroAPI Agents repository guidance

- This branch is the public, auditable installer for NeuroAPI integrations with Codex CLI and Claude Code.
- Never accept API keys through command-line arguments, persist them as plaintext, or print them outside the dedicated credential helpers.
- Windows secrets must stay DPAPI-protected for the current user. macOS secrets must stay in the current user's login Keychain.
- Do not overwrite unrelated Codex, Claude Code, shell, or PATH configuration. Update and uninstall only files marked as installer-owned.
- Keep Windows PowerShell 5.1 compatibility and macOS system Bash compatibility.
- Validate script syntax, generated TOML/JSON, idempotency, secret handling, and uninstall boundaries before publishing.

- Codex CLI uses a user-level profile-v2 file, `https://codex.neuroapi.host/v1`, and WebSocket by default; the optional Codex Desktop setup uses the same host with HTTP/SSE. Publish installers only after authenticated catalog and transport checks.
- Keep unsupported hosted Codex tools (`web_search`, multi-agent namespace, goals, apps and browser use) disabled in this profile until the server can execute and bill them safely; local file and shell tools must remain available.
- Managed launchers fetch and validate fresh key-scoped catalogs into private per-launch snapshots; never fall back to stale/bundled lists or accept executable server settings. Claude Code's base URL is `https://claude.neuroapi.host`; Claude Desktop gateway is configured separately in its UI. Keep ordinary keys, preserve unrelated configuration, and document managed-policy/explicit-override boundaries.

- Claude client-settings v2 is opt-in via `X-NeuroAPI-Client-Settings-Version: 2`; accept only the three reviewed limit/hint env keys with canonical bounded decimal strings (or hint `1`), retain the 4096 output fallback for old servers. `--doctor` performs no generation; `--doctor-generate` explicitly opts into one bounded HTTP probe with no retries, secret-free output and no claim of WebSocket/tool compatibility.
