# Implementation plan

1. Create a clean orphan `agents` branch while keeping `main` and all historical branches intact.
2. Implement Windows entrypoints, DPAPI storage, credential helper, isolated configs, launchers, PATH registration, and bounded uninstall.
3. Implement macOS entrypoints, Keychain storage, credential helper, isolated configs, launchers, and bounded uninstall.
4. Add Russian-first README, English quick reference, security model, manual setup, troubleshooting, and MIT license.
5. Add cross-platform static validation plus platform-specific installer smoke tests with dummy credentials only.
6. Run final validation and independent review.
7. Push `legacy-web-ui-2024` and `agents`, switch the GitHub default branch to `agents`, and update repository metadata.
8. Link the live repository from the NeuroAPI `/codex-api` and `/claude-code` public pages.
