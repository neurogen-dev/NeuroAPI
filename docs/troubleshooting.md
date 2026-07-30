# Troubleshooting

## Codex CLI does not pick up the NeuroAPI profile

- verify that you are using the intended profile name;
- run `/debug-config` and inspect the effective provider block;
- check that the helper can read the current user's secret store;
- make sure the profile was created in the user-level config, not the project config.

## Claude Code ignores the NeuroAPI settings file

- verify the settings file path you passed to the CLI;
- run `/status` and confirm the base URL and credential source;
- ensure the secret helper prints only the token and nothing else;
- confirm that an old global config is not taking precedence.

## Secret seems to be saved in plaintext

- stop and remove the generated file;
- confirm the setup was run in test mode or interactive mode;
- re-run the setup and verify the storage backend is DPAPI or Keychain only;
- inspect the repository for accidental secret fixtures before publishing.

## I changed my key

- update the stored secret in the current user's secure store;
- re-run the profile generation step;
- verify again with `/debug-config` and `/status`.

## Still stuck

Document:

- operating system;
- Codex CLI or Claude Code;
- the command you ran;
- the exact point where the configuration diverged from the expected one.
