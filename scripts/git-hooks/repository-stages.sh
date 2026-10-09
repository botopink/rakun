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
# The claim no `test { }` block can check: a literal whose every hole is known
# at build is computed at build (decision 355) — the emitted module calls the
# constant constructor with the class and the rules as literals, nothing hashed
# when the program runs — and one with a hole computed at render is not. The
# example application is built on both targets and its module read: `tab4 =
# styledProperty "tab-size: 4;"` (no hole) and `tabRed = styled "${tab4} color:
# red;"` (a hole naming a `val` known at build) are constants; `code`, whose
# `${padAll(2)}` is a call, is computed.

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
        erlang)
            want='propertyConstant(undefined, <<"s_e8b00b8b">>, <<".s_e8b00b8b{tab-size:4}">>'
            known='styledConstant(undefined, <<"s_b480a37a">>, <<".s_b480a37a{tab-size:4;color:red}">>)'
            render='code}, __BpV)'
            ;;
        commonJS)
            want='propertyConstant(null, "s_e8b00b8b", ".s_e8b00b8b{tab-size:4}"'
            known='styledConstant(null, "s_b480a37a", ".s_b480a37a{tab-size:4;color:red}")'
            render='const code = '
            ;;
    esac
    if ! grep -rF -- "$want" "$out" >/dev/null; then
        rm -rf "$out"
        fail "$target: tab4's class is not a constant of the emitted module — a literal with no hole is computed at build"
    fi
    if ! grep -rF -- "$known" "$out" >/dev/null; then
        rm -rf "$out"
        fail "$target: tabRed's class is not a constant of the emitted module — a literal whose every hole is known at build is computed at build (decision 355)"
    fi
    if ! grep -rhF -- "$render" "$out" | grep -F 'styledComputed(' >/dev/null; then
        rm -rf "$out"
        fail "$target: code is not computed at render — its \${padAll(2)} hole is a call"
    fi
    rm -rf "$out"
done
pass "build-time components: tab4 and tabRed are constants of the emitted module, code is computed, on erlang and commonJS"
