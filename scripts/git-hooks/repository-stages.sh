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
# `${padAll(2)}` is a call, is computed — a component function that passes the
# map it received to `styledComputed`, which reads `StyledContext` there
# (decisions 352, 354), and runs its splice through `splice`.

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
            render='code(BpContextMap__) ->'
            computed='styledComputed(BpContextMap__, <<"s_">>'
            ;;
        commonJS)
            want='propertyConstant(null, "s_e8b00b8b", ".s_e8b00b8b{tab-size:4}"'
            known='styledConstant(null, "s_b480a37a", ".s_b480a37a{tab-size:4;color:red}")'
            render='function code(bpContextMap__) {'
            computed='styledComputed(bpContextMap__, "s_"'
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
    if ! grep -rh -A1 -F -- "$render" "$out" | grep -F -- "$computed" >/dev/null; then
        rm -rf "$out"
        fail "$target: code is not computed at render under the map it received — its \${padAll(2)} hole is a call"
    fi
    if ! grep -rh -A3 -F -- "$render" "$out" | grep -F 'splice(' >/dev/null; then
        rm -rf "$out"
        fail "$target: code's \${padAll(2)} splice does not run through splice — a splice registers nothing"
    fi
    rm -rf "$out"
done
pass "build-time components: tab4 and tabRed are constants of the emitted module, code is computed under its map, on erlang and commonJS"

# The claim of decisions 352 and 354: a component computed at render registers
# its class and rules in the sheet its render provides through `use
# context(StyledContext)`, and nothing else does. `examples/styled-context`
# provides a sheet whose writer prints each registration — its stdout is
# `expected.out` byte for byte: a computed `styled` registers every time it
# runs (the provider's sheet keeps it once), a `${p}` splice registers
# nothing, a literal computed at build registers nothing, a property standing
# on its own registers itself. `examples/styled-context-unbound` renders the
# same kind of literal with no provider above it: it prints `before` and
# aborts `context-unbound`, naming `StyledContext` (its `expected.stderr`).
for target in erlang commonJS; do
    for name in styled-context styled-context-unbound; do
        app="$gate_root/examples/$name"
        [ -f "$app/expected.out" ] || fail "examples/$name/expected.out is missing — the context stage has nothing to compare"
        out=$(mktemp -d)
        got="$out/stdout"
        err="$out/stderr"
        # An erlang abort writes its crash dump where it runs: into the scratch dir.
        # The runner runs under `set -e`: an abort is read, not let out.
        status=0
        ( cd "$app" && ERL_CRASH_DUMP="$out/erl_crash.dump" "$bin" run --target "$target" --out "$out/build" ) >"$got" 2>"$err" \
            || status=$?
        if [ -f "$app/expected.stderr" ]; then
            if [ "$status" -eq 0 ]; then
                rm -rf "$out"
                fail "$target: examples/$name ran to the end — a read of StyledContext with no provider above it is context-unbound"
            fi
            if ! grep -qF -- "$(head -n 1 "$app/expected.stderr")" "$err"; then
                rm -rf "$out"
                fail "$target: examples/$name aborted without naming context-unbound on StyledContext"
            fi
        elif [ "$status" -ne 0 ]; then
            rm -rf "$out"
            fail "$target: examples/$name does not run (exit $status)"
        fi
        if ! cmp -s "$app/expected.out" "$got"; then
            rm -rf "$out"
            fail "$target: examples/$name's output differs from its expected.out"
        fi
        rm -rf "$out"
    done
done
pass "StyledContext: a component computed at render registers through the render's provider, a splice and a constant register nothing, no provider is context-unbound, on erlang and commonJS"
