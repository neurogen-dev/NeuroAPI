# NeuroAPI for Codex CLI and Claude Code

Public, auditable one-click setup for routing local Codex CLI and Claude Code sessions through [NeuroAPI](https://neuroapi.host) on Windows and macOS.

[Русская версия](README.md)

## Release compatibility

This version configures `https://neuroapi.host/v1/codex` with `supports_websockets = true`, and `https://neuroapi.host/v1/claude-code` for Claude Code. The Codex profile disables hosted web search, multi-agent, goals, apps, and browser use because the current client includes these tools even in simple local tasks, while NeuroAPI does not guarantee their upstream execution. Local shell and file tools remain available. Publish or distribute it **only after the server profiles are deployed** and authenticated `/v1/codex/models`, HTTP/WebSocket `/v1/codex/responses`, `/v1/claude-code/client-settings`, and Claude Messages/count_tokens checks pass. Local implementation is not production evidence. Setup deliberately does not call the API to validate credentials; launchers fetch the current catalog before starting a client.

An existing `CODEX_HOME` selects the profile directory without being modified. Keep its value consistent for setup, launch and uninstall.

Use a current Codex release whose `--help` describes `--profile` as loading `<name>.config.toml`. Update older clients that expect `[profiles.name]` in the main configuration. For WebSocket troubleshooting, temporarily set `supports_websockets = false` in the generated profile, keeping `/v1/codex` and its credential helper.

## Quick start

Install [Codex CLI](https://developers.openai.com/codex/cli/) and/or [Claude Code](https://code.claude.com/docs/en/installation), then create a key in the [NeuroAPI dashboard](https://neuroapi.host/login?redirect=/dashboard/tokens).

Windows:

1. [Download the agents ZIP](https://github.com/neurogen-dev/NeuroAPI/archive/refs/heads/agents.zip).
2. Extract it and double-click `setup-windows.bat`.
3. Paste the key into the masked PowerShell prompt.
4. Open a new terminal and run `codex-neuroapi` or `claude-neuroapi`.

macOS:

1. Download and extract the same ZIP.
2. Run `chmod +x setup-macos.command && ./setup-macos.command`.
3. Paste the key into the macOS Keychain prompt.
4. Run `~/.local/bin/codex-neuroapi` or `~/.local/bin/claude-neuroapi`.

The setup does not require administrator privileges, does not use `sudo`, and does not overwrite existing Codex, Claude Code, or shell configuration.

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
- Check current model IDs and pricing at [neuroapi.host/price](https://neuroapi.host/price).

Each launcher fetches a fresh catalog scoped to the ordinary NeuroAPI key. Codex uses a private `model_catalog_json`; Claude receives a configured picker. There are no hardcoded default models. Codex 0.147.0+ and Claude Code 2.1.280+ are required. Invalid, empty or unavailable catalogs stop launch instead of restoring stale lists. Organization policies and deliberate CLI overrides retain their documented precedence; these launchers do not support host-managed provider mode.

Recommended server selection as of 2026-09-26: GPT-6 Sol, Astra and Luna for Codex; **Opus 5.5** (`claude-opus-5-5`, preferred), Sonnet 5, Haiku 4.5 and Fable 5.1 for Claude Code. Opus 5.5 becomes the default after publication and key eligibility; otherwise the next available recommendation is selected. Official ID: [Anthropic](https://www.anthropic.com/claude/opus).

## More

- [Security model](docs/security.md)
- [Manual setup and installed paths](docs/manual-setup.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Codex guide](https://neuroapi.host/codex-api)
- [Claude Code guide](https://neuroapi.host/claude-code)
- [NeuroAPI documentation](https://neuroapi.host/docs/getting-started)
