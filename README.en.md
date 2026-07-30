# NeuroAPI Agents

Public, auditable setup docs for connecting NeuroAPI to Codex CLI and Claude Code.

The safety model is simple: the user types the key into an interactive terminal, the key is never kept in plaintext, and the setup targets only the current user profile.

Official site:

[neuroapi.host](https://neuroapi.host)

What is already in the repository:

- Windows setup/uninstall wrappers and PowerShell implementation in `scripts/windows/`;
- macOS setup/uninstall wrappers and shell implementation in `scripts/macos/`;
- static publication checks in `tests/` and the GitHub Actions workflow;
- public docs for security, manual setup, and troubleshooting;
- a research ledger with decisions and the implementation plan.

Security goals:

- interactive key entry only;
- Windows secret storage via DPAPI for the current user;
- macOS secret storage in the current user's login Keychain;
- no wholesale overwrite of existing user configuration;
- no secret material in logs, docs, or CI output;
- validation limited to structure, fixtures, and storage boundaries.

What this repo documents:

- Codex CLI setup flow;
- Claude Code setup flow;
- secret-handling model;
- manual setup;
- troubleshooting;
- static validation for the public repository surface.

Version drift warning:

Model names, base URLs, and provider settings can change. Always confirm the live configuration with Codex `/debug-config` and Claude Code `/status`, and compare against the official vendor documentation before publishing or reusing a preset.
