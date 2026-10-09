#!/usr/bin/env bash
# repository-stages.sh — the stage of the pre-commit gate only styled has.
#
# `scripts/git-hooks/lib/runner-standalone.sh` is one text in every library
# repository; what is styled's own lives here. The runner sources this file in
# a child bash process (stage 3, `runRepositoryStagesGate`), from the
# repository root, after it has sourced itself — so `fail`, `pass`,
# `requireBotopink` and `gate_root` are available. This file can only ADD a red.
# CI runs it too (the workflow's hook-stages step).
#
# The claim no `test { }` block can check: a literal with no hole is computed
# at build — the emitted module calls the constant constructor with the class
# and the rules as literals, nothing hashed when the program runs. The example
# application's `tab4 = styledProperty "tab-size: 4;"` is built on both targets
# and its module read for the literal class.

bin=$(requireBotopink)
example="$gate_root/examples/styled-example"
[ -f "$example/botopink.json" ] || fail "examples/styled-example is missing — the build-time stage has nothing to build"

for target in erlang commonJS; do
    out=$(mktemp -d)
    ( cd "$example" && "$bin" build --target "$target" --out "$out" ) >/dev/null 2>&1 \
        || { rm -rf "$out"; fail "examples/styled-example does not build on $target"; }
    # A component function takes the hidden context map first (decision 354):
    # a call outside a render passes none — `undefined` on erlang, `null` on commonJS.
    case "$target" in
        erlang) want='propertyConstant(undefined, <<"s_e8b00b8b">>, <<".s_e8b00b8b{tab-size:4}">>' ;;
        commonJS) want='propertyConstant(null, "s_e8b00b8b", ".s_e8b00b8b{tab-size:4}"' ;;
    esac
    if ! grep -rF -- "$want" "$out" >/dev/null; then
        rm -rf "$out"
        fail "$target: tab4's class is not a constant of the emitted module — a literal with no hole is computed at build"
    fi
    rm -rf "$out"
done
pass "build-time components: tab4's class is a constant of the emitted module on erlang and commonJS"
