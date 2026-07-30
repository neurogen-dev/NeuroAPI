#!/bin/bash
set -euo pipefail

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"

/bin/bash -n "$REPO_ROOT/setup-macos.command"
/bin/bash -n "$REPO_ROOT/uninstall-macos.command"
for script in "$REPO_ROOT"/scripts/macos/*.sh; do
  /bin/bash -n "$script"
done

printf 'macOS shell syntax validation passed.\n'
