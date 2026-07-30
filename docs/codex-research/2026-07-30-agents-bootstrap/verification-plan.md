# Verification plan

## Static

- PowerShell parser accepts every `.ps1`.
- `bash -n` accepts every `.sh` and `.command`.
- ShellCheck passes for shell scripts.
- Generated Claude settings parse as JSON.
- Generated Codex profiles parse as TOML.
- Repository scan finds no API-key-shaped secret or plaintext key storage.

## Windows

- Test-mode install uses a dummy value, produces a DPAPI ciphertext, and never prints the dummy token.
- Credential helper returns exactly the decrypted dummy token.
- Existing unrelated Codex profile is not overwritten.
- Re-running the installer is idempotent for installer-owned files and PATH.
- Test-mode uninstall removes only installer-owned files and profile.

## macOS

- Mocked `security` verifies `-w` is passed last with no secret argument.
- Generated helper calls `find-generic-password` and prints no labels.
- Re-running configuration is idempotent.
- Uninstall targets only the package Keychain item and installer-owned files.

## GitHub

- Legacy branch commit equals the previous `origin/main` commit.
- `agents` is pushed without force.
- GitHub default branch changes only after validation passes.
- Repository description, homepage, and topics match the new public purpose.
