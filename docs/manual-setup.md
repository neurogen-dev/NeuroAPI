# Manual setup

If you do not want to use the one-click wrapper yet, the safe manual setup is:

## Codex CLI

1. Install Codex CLI using the official method.
2. Create a dedicated user-level profile for NeuroAPI.
3. Enter the API key only into the interactive prompt or secure helper.
4. Keep the provider isolated from your personal/default config.
5. Confirm the result with `codex --profile <name> /debug-config`.

## Claude Code

1. Install Claude Code using the official method.
2. Create an isolated settings file for NeuroAPI.
3. Store the key through the documented helper path.
4. Point the CLI at the dedicated settings file.
5. Confirm the result with `claude /status`.

## What not to do

- do not pass the key on the command line;
- do not paste the key into a tracked file;
- do not overwrite your existing Codex or Claude Code profile;
- do not use a shared machine-level secret store for a personal setup;
- do not rely on a model name copied from an old post without checking current docs.

## Practical baseline

Use the official NeuroAPI endpoint and a current supported model name, then verify the active configuration before first use. If the model or gateway name has changed, update the profile rather than keeping a stale preset.
