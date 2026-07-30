# Findings

## Existing repository

- Repository: `neurogen-dev/NeuroAPI`.
- Visibility: public.
- Current default branch before this batch: `main`.
- Existing branches: `main`, `free`, `old-chat`, `old-portable`, `v2.0-dev`.
- The old default branch points to a 2024 web/desktop client. It will remain untouched and will also be preserved as `legacy-web-ui-2024`.

## Codex CLI

- Current Codex profiles are separate files named `~/.codex/<profile>.config.toml`.
- A custom provider can use command-backed bearer authentication.
- The auth helper receives no stdin and must print only the token to stdout.
- Project `.codex/config.toml` cannot redirect `model_provider` or `model_providers`, so the installer must create a user-level profile.
- `wire_api = "responses"` is the currently documented custom-provider protocol.

## Claude Code

- `ANTHROPIC_BASE_URL` selects a gateway endpoint.
- `apiKeyHelper` is a supported credential command and its output is used for request authentication.
- `--settings <file>` has command-line precedence and can point at an isolated installer-owned JSON file.
- `/status` and `claude doctor` are the documented verification surfaces.

## Secret storage

- PowerShell `ConvertFrom-SecureString` without a supplied key uses Windows DPAPI. The encrypted value can be decrypted only in the matching current-user/machine context.
- macOS `security add-generic-password ... -w` with `-w` placed last prompts for the secret instead of receiving it in process arguments.
- Neither installer needs a plaintext `.env`, config value, command-line argument, or persistent environment variable.
