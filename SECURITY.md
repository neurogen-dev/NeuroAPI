# Security Policy

## Supported versions

Only the current public documentation branch is supported.

## Secret handling model

This repository is built around a narrow security posture:

- the user enters the API key manually at setup time;
- the key is never accepted through a command-line argument;
- the key is never stored in plaintext files;
- Windows uses DPAPI for the current user;
- macOS uses the login Keychain for the current user;
- installer-owned files are the only files that may be written or removed by setup and uninstall flows.

## Threat model

In scope:

- accidental plaintext storage;
- logging of secret values;
- overwriting an existing Codex or Claude Code configuration;
- leaking a secret through generated examples or CI logs;
- unsafe PATH registration or uninstall scope.

Out of scope:

- compromise of the operating system;
- compromise of the user's shell profile outside installer-owned boundaries;
- vendor-side provider outages or model drift.

## Responsible disclosure

If you find a secret-handling issue, a configuration overwrite path, or a validation gap that could expose credentials, report it privately to NeuroAPI before public disclosure.

Please include:

- affected file or command;
- operating system;
- whether the issue involves plaintext storage, logs, PATH changes, or uninstall behavior;
- the exact reproduction steps.
