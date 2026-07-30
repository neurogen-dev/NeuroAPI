# Work log

## 2026-07-30

- Confirmed the authenticated GitHub owner is `neurogen-dev`.
- Confirmed `neurogen-dev/NeuroAPI` is public and currently defaults to `main`.
- Inspected existing branches and the old default tree.
- Cloned to `C:\ai\neuroapi-agents-public`.
- Created local preservation branch `legacy-web-ui-2024` at the exact previous `origin/main` commit.
- Created clean orphan branch `agents`.
- Verified current official Codex custom-provider/profile and Claude Code gateway/helper contracts.
- Chose DPAPI CurrentUser on Windows and login Keychain on macOS.
- A documentation-only subagent prematurely pushed commit `ef597b4` to the non-default `agents` branch. The old default branch remained unchanged; the controller kept the branch and replaced the incomplete implementation in a follow-up batch.
- Rejected two generated installer drafts after review because they exposed plaintext in process-local strings, used invalid Claude settings fields, placed the Codex profile outside its discovery path, or edited unrelated shell configuration.
- Implemented the controller-owned Windows flow with direct SecureString-to-DPAPI protection, isolated profile/settings, narrow markers, idempotent PATH handling, and bounded uninstall.
- Implemented the controller-owned macOS flow with Keychain's own interactive `-w` prompt, no key shell variable or pipe, isolated profile/settings, narrow markers, and no shell-profile edits.
- Reworked the Russian-first repository landing page, English companion, security model, manual setup, troubleshooting, and three-platform CI.
- Linked the future public installer source from the NeuroAPI Codex and Claude Code GEO pages; SEO branch merge remains paused.
- Independent review found that a colliding, unmarked macOS Keychain item could be updated or deleted. Added a dedicated Keychain ownership marker, refusal on pre-existing unowned items, and a regression smoke case.
- Real Windows smoke reproduced inherited PowerShell 7 module paths breaking the Windows PowerShell DPAPI helper when Claude invokes it through `cmd`. Public wrappers now clear the inherited module path and the helper pins Windows PowerShell's built-in modules.
- Rechecked the current OpenAI project-config contract: `model_provider` and `model_providers` are intentionally ignored in project-local `.codex/config.toml`, so the user-level profile remains required.
- Local static validation, PowerShell syntax, DPAPI/helper smoke (including actual `cmd.exe` execution), Bash syntax, and `git diff --check` pass. ShellCheck and native macOS behavior remain GitHub Actions gates.
- Independent final verification repeated the static, Windows syntax, Windows DPAPI/helper smoke, Bash syntax, staged diff, workflow, and executable-mode checks successfully. Native macOS smoke remains intentionally deferred to the `macos-latest` CI runner.
