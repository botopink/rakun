#!/usr/bin/env bash
# check-refusals.sh — run the refusals stage of the pre-commit gate alone:
# every `refusals/<case>/` project is refused by `botopink check` with the
# lines of its `expect.txt` (see runRefusalsGate in
# scripts/git-hooks/lib/runner-standalone.sh). The compiler is found as the gate
# finds it: $BOTOPINK_BIN, an ancestor's zig-out/bin, or $PATH.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=git-hooks/lib/runner-standalone.sh
. scripts/git-hooks/lib/runner-standalone.sh
bin=$(requireBotopink)
runRefusalsGate "$bin"
