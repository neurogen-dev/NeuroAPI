# Security model

This repository documents the safe setup path for NeuroAPI with Codex CLI and Claude Code.

## Core rule

The user types the API key into the terminal during setup. The repository never needs to ship the key in plaintext, a command argument, or a checked-in environment file.

## Windows

- store the secret with DPAPI under the current user context;
- do not write a reusable plaintext secret file;
- do not reuse another user's profile or machine context;
- keep installer-owned files separate from existing Codex or Claude settings.

## macOS

- store the secret in the current user's login Keychain;
- do not echo the secret in the shell;
- do not place the secret into a repo file or a shared environment export;
- keep installer-owned files separate from existing settings.

## Configuration boundaries

The setup should create isolated files for:

- a Codex CLI profile;
- a Claude Code settings file;
- optional helper launchers owned by the installer.

It should not:

- overwrite existing user-wide settings;
- modify unrelated shell startup files;
- depend on a plaintext `.env` file;
- print token values in verification output.

## Validation boundaries

The public repository should validate:

- file syntax;
- fixture structure;
- absence of obvious secret patterns;
- idempotent installer-owned paths;
- non-overwrite behavior.

The public repository should not validate with real secrets or real provider calls in CI.
