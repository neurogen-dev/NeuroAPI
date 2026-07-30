# Security policy

Do not open a public issue containing an API key, decrypted credential, personal data, or an exploit that would expose other users.

Report credential handling, unsafe overwrite, command injection, or destructive uninstall findings to `support@neuroapi.host` with the subject `SECURITY: NeuroAPI GitHub installer`.

Include:

- affected operating system and version;
- affected file and commit;
- minimal reproduction steps without a real key;
- expected and actual behavior;
- whether public disclosure is already known.

We do not ask for a real API key to reproduce an installer issue.

The supported branch is the current GitHub default branch (`agents`). Legacy application branches are preserved for history but are not covered by this installer security policy.

See [docs/security.md](docs/security.md) for the threat model and explicit limitations.
