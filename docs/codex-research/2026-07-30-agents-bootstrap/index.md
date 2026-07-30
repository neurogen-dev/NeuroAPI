# NeuroAPI Agents bootstrap

Status: Ready for publication

## Objective

Replace the public repository default surface with an auditable one-click setup for NeuroAPI in Codex CLI and Claude Code while preserving every existing branch and the previous default branch.

## Scope

- Windows interactive installer and DPAPI-backed credential helper.
- macOS interactive installer and Keychain-backed credential helper.
- Isolated Codex profile and isolated Claude Code settings.
- Safe launchers, uninstallers, documentation, and CI validation.
- GitHub branch preservation and default-branch switch only after validation.

## Non-goals

- Installing Codex CLI or Claude Code themselves.
- Modifying existing user-wide Codex or Claude configuration.
- Sending, validating, or otherwise transmitting an API key during installation.
- Rewriting or deleting legacy Git history.
