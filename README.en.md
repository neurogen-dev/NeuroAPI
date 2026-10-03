# NeuroAPI for Codex CLI and Claude Code

Public, auditable guided setup for routing local Codex CLI and Claude Code sessions through [NeuroAPI](https://neuroapi.host) on Windows and macOS. It configures the terminal launchers `codex-neuroapi` and `claude-neuroapi`. With separate consent, it also configures **Codex Desktop** in the user-level `~/.codex/config.toml`. See the [Claude Desktop guide](https://neuroapi.host/docs/claude-desktop) for that application's own setup.

[Русская версия](README.md)

## Release compatibility

This version configures `https://codex.neuroapi.host/v1` with `supports_websockets = true`, and `https://claude.neuroapi.host` for Claude Code. The Codex profile enables hosted web search through NeuroAPI (`web_search = "live"`) and disables plugins in the separate CLI profile (`plugins = false`, `remote_plugin = false`) so API-key startup does not depend on ChatGPT/Git plugin catalog synchronization. Shell, file tools and separately configured MCP servers remain available. Desktop keeps the user's existing `plugins` preference; users who do not need plugins can disable them manually. Multi-agent, goals, apps and browser use remain disabled in the CLI profile until their execution is independently verified. Setup checks both key-scoped catalogs without a paid generation. After setup, send one short real request and confirm it in your [NeuroAPI usage log](https://neuroapi.host/dashboard/logs); a catalog check alone does not prove generation works.

An existing `CODEX_HOME` selects the profile directory without being modified. Keep its value consistent for setup, launch and uninstall.

Use a current Codex release whose `--help` describes `--profile` as loading `<name>.config.toml`. Update older clients that expect `[profiles.name]` in the main configuration. For WebSocket troubleshooting, temporarily set `supports_websockets = false` in the generated profile, keeping `https://codex.neuroapi.host/v1` and its credential helper.

## Quick start

Create a key in the [NeuroAPI dashboard](https://neuroapi.host/login?redirect=/dashboard/tokens). Setup installs or updates missing/old Codex CLI and Claude Code from their [official Codex](https://developers.openai.com/codex/cli/) and [official Claude Code](https://code.claude.com/docs/en/setup) sources.

The ZIP link points to the published `agents` branch. Changes in an open pull request reach that archive only after the pull request is merged into `agents`.

Windows:

1. [Download the agents ZIP](https://github.com/neurogen-dev/NeuroAPI/archive/refs/heads/agents.zip).
2. Extract it and double-click `setup-windows.bat`.
3. Paste the key into the masked PowerShell prompt.
4. If you use Codex Desktop, choose the optional Desktop setup and restart the app. Your original user config is backed up.
5. Open a new terminal and run `codex-neuroapi` or `claude-neuroapi`.

macOS:

1. Download and extract the same ZIP.
2. In the extracted directory, run `bash setup-macos.command`.
3. Paste the key into the macOS Keychain prompt.
4. If you use Codex Desktop, choose the optional Desktop setup and restart the app. Your original user config is backed up.
5. Run `~/.local/bin/codex-neuroapi` or `~/.local/bin/claude-neuroapi`.

The setup does not require administrator privileges or `sudo`. Codex Desktop integration edits the user config only after consent, with a guarded backup and conflict checks.

Claude Desktop is configured separately in the app's official Developer Mode → Configure Third-Party Inference screen. The installer does not silently change the app's private settings; follow the [Claude Desktop guide](https://neuroapi.host/docs/claude-desktop). If an older connection failed, follow the [reconnection guide](docs/reconnect-after-update.md) before retrying.

For a manual alternative, the [copy-and-paste guide (Russian)](docs/copy-paste-setup.md) lists the exact Windows/macOS file paths, Codex CLI and Claude Code snippets, Codex Desktop setup using the installer's protected credential helper, and the Claude Desktop form fields. It keeps the real key out of TOML and JSON.

## Secret model

- The key is never accepted as a setup command-line argument.
- Windows stores only DPAPI ciphertext bound to the current user and computer.
- macOS stores the key in the current user's login Keychain.
- Codex uses command-backed provider authentication.
- Claude Code uses `apiKeyHelper` from an isolated `--settings` file.
- No key is written to TOML, JSON, `.env`, Git, or CI.

This prevents accidental plaintext disclosure. It does not protect a key from malware already running as the same OS user. See [docs/security.md](docs/security.md) for the full boundary.

## Verification

- In `codex-neuroapi`, run `/debug-config` and confirm the `neuroapi-host` profile and `https://codex.neuroapi.host/v1`.
- In `claude-neuroapi`, run `/status` and confirm `https://claude.neuroapi.host` plus `apiKeyHelper`.
- For Codex Desktop, check a new local task, `https://codex.neuroapi.host/v1` in the user config, and the request in your NeuroAPI usage logs. Setup uses HTTP/SSE for this GUI integration.
- Check current model IDs and pricing at [neuroapi.host/price](https://neuroapi.host/price).

Each launcher fetches a fresh catalog scoped to the ordinary NeuroAPI key. Codex uses a private `model_catalog_json`; Claude receives a configured picker. There are no hardcoded default models. Tested minimum versions are Codex 0.158.0 and Claude Code 2.1.284. The Claude launcher requests v2 settings and accepts strictly validated context/output limits and gateway hint headers. Older servers retain the 4096-token output fallback; output limits are independent of financial reservation estimates. Invalid, empty or unavailable catalogs stop launch instead of restoring stale lists. Organization policies and deliberate CLI overrides retain their documented precedence; these launchers do not support host-managed provider mode.

Recommended server selection: GPT-6 Sol, Astra and Luna for Codex; **Opus 5.5** (`claude-opus-5-5`, preferred), Sonnet 5.5, Sonnet 5 and Fable 5.1 for Claude Code. An entry appears only when its published model, tariff and compatible upstream route are available to the key. Existing administrator catalog settings override source defaults.

Claude Code also uses the `haiku` alias for background work. If no recommended Haiku is available, the server maps that alias to an eligible Sonnet or the default model. These requests are billed for the actual selected model and may cost more than Haiku.

## More

- [Security model](docs/security.md)
- [Manual setup and installed paths](docs/manual-setup.md)
- [Manual copy-and-paste setup (Russian)](docs/copy-paste-setup.md)
- [Reconnect after an older failed setup](docs/reconnect-after-update.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Codex guide](https://neuroapi.host/codex-api)
- [Claude Code guide](https://neuroapi.host/claude-code)
- [Codex Desktop guide](https://neuroapi.host/docs/codex-desktop)
- [Claude Desktop guide](https://neuroapi.host/docs/claude-desktop)
- [NeuroAPI documentation](https://neuroapi.host/docs/getting-started)

## Connection diagnostics

Run `codex-neuroapi --doctor` or `claude-neuroapi --doctor` to validate the client version
and protected key's access to the current model catalog. The key is not printed and no
paid generation occurs. `--doctor-generate` explicitly requests one small **billable** HTTP
generation and measures its duration, without retries. It validates a completed nonempty
answer; it does not prove WebSocket, client tools, GUI sessions or deliberate overrides.
Organization provider policies remain authoritative. Temporary snapshots are removed.
