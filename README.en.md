# NeuroAPI for Codex CLI and Claude Code

Public, auditable guided setup for routing local Codex CLI and Claude Code sessions through [NeuroAPI](https://neuroapi.host) on Windows and macOS. It configures the terminal launchers `codex-neuroapi` and `claude-neuroapi`. With separate consent, it also configures **Codex Desktop** in the user-level `~/.codex/config.toml`. See the [Claude Desktop guide](https://neuroapi.host/docs/claude-desktop) for that application's own setup.

[Русская версия](README.md)

## Release compatibility

This version configures `https://neuroapi.host/v1/codex` with `supports_websockets = true`, and `https://neuroapi.host/v1/claude-code` for Claude Code. The Codex profile disables hosted web search, multi-agent, goals, apps, and browser use because the current client includes these tools even in simple local tasks, while NeuroAPI does not guarantee their upstream execution. Local shell and file tools remain available. Setup checks both key-scoped catalogs without a paid generation. Verify HTTP/WebSocket Responses and Claude Messages/count_tokens after each server release.

An existing `CODEX_HOME` selects the profile directory without being modified. Keep its value consistent for setup, launch and uninstall.

Use a current Codex release whose `--help` describes `--profile` as loading `<name>.config.toml`. Update older clients that expect `[profiles.name]` in the main configuration. For WebSocket troubleshooting, temporarily set `supports_websockets = false` in the generated profile, keeping `/v1/codex` and its credential helper.

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

## Secret model

- The key is never accepted as a setup command-line argument.
- Windows stores only DPAPI ciphertext bound to the current user and computer.
- macOS stores the key in the current user's login Keychain.
- Codex uses command-backed provider authentication.
- Claude Code uses `apiKeyHelper` from an isolated `--settings` file.
- No key is written to TOML, JSON, `.env`, Git, or CI.

This prevents accidental plaintext disclosure. It does not protect a key from malware already running as the same OS user. See [docs/security.md](docs/security.md) for the full boundary.

## Verification

- In `codex-neuroapi`, run `/debug-config` and confirm the `neuroapi-host` profile and `https://neuroapi.host/v1/codex`.
- In `claude-neuroapi`, run `/status` and confirm `https://neuroapi.host/v1/claude-code` plus `apiKeyHelper`.
- For Codex Desktop, check a new local task, `https://codex.neuroapi.host/v1` in the user config, and the request in your NeuroAPI usage logs. Setup uses HTTP/SSE for this GUI integration.
- Check current model IDs and pricing at [neuroapi.host/price](https://neuroapi.host/price).

Each launcher fetches a fresh catalog scoped to the ordinary NeuroAPI key. Codex uses a private `model_catalog_json`; Claude receives a configured picker. There are no hardcoded default models. Tested minimum versions are Codex 0.158.0 and Claude Code 2.1.284. The Claude launcher limits initial output to 4096 tokens to bound quota reservation. Invalid, empty or unavailable catalogs stop launch instead of restoring stale lists. Organization policies and deliberate CLI overrides retain their documented precedence; these launchers do not support host-managed provider mode.

Recommended server selection: GPT-6 Sol, Astra and Luna for Codex; **Opus 5.5** (`claude-opus-5-5`, preferred), Sonnet 5.5, Sonnet 5 and Fable 5.1 for Claude Code. An entry appears only when its published model, tariff and compatible upstream route are available to the key. Existing administrator catalog settings override source defaults.

Claude Code also uses the `haiku` alias for background work. If no recommended Haiku is available, the server maps that alias to an eligible Sonnet or the default model. These requests are billed for the actual selected model and may cost more than Haiku.

## More

- [Security model](docs/security.md)
- [Manual setup and installed paths](docs/manual-setup.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Codex guide](https://neuroapi.host/codex-api)
- [Claude Code guide](https://neuroapi.host/claude-code)
- [Codex Desktop guide](https://neuroapi.host/docs/codex-desktop)
- [Claude Desktop Code guide](https://neuroapi.host/docs/claude-desktop)
- [NeuroAPI documentation](https://neuroapi.host/docs/getting-started)
