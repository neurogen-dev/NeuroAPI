# NeuroAPI for Codex CLI and Claude Code

Public, auditable one-click setup for routing local Codex CLI and Claude Code sessions through [NeuroAPI](https://neuroapi.host) on Windows and macOS.

[Русская версия](README.md)

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

- In `codex-neuroapi`, run `/debug-config` and confirm the `neuroapi-host` profile and `https://neuroapi.host/v1`.
- In `claude-neuroapi`, run `/status` and confirm `https://neuroapi.host` plus `apiKeyHelper`.
- Check current model IDs and pricing at [neuroapi.host/price](https://neuroapi.host/price).

The installer defaults are examples and may drift with provider catalogs.

## More

- [Security model](docs/security.md)
- [Manual setup and installed paths](docs/manual-setup.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Codex guide](https://neuroapi.host/codex-api)
- [Claude Code guide](https://neuroapi.host/claude-code)
- [NeuroAPI documentation](https://neuroapi.host/docs/getting-started)
