#!/usr/bin/env bash
# runner-standalone.sh — the pre-commit gate of a botopink library.
#
# Sourced by scripts/git-hooks/pre-commit. It is the only runner: it needs
# nothing outside this repository (standalone clone, meta checkout, worktree,
# bpmp packing). Stages: conflict markers in staged files, `botopink test`
# (per member under modules/*/ when the root botopink.json is a workspace —
# decision 75: the umbrella compiles nothing and `botopink test` there is a
# refusal — else over the package's own src/ + test/), then `botopink build`
# of every example (runExamplesGate — CI calls it too).
#
# Fail beats warn (decision 67): a compiler binary that cannot be found fails
# the gate, a staged `*.snap.new` / `*.snap.md.new` fails the gate, and there
# is no list of examples allowed to fail.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }
pass() { echo -e "${GREEN}✓ $1${NC}"; }

# The compiler binary, or a failure that says how to provide one. Never a
# warning: a gate that skips its `.bp` stage gates nothing.
requireBotopink() {
    local bin
    if bin=$(locateBotopink); then
        echo "$bin"
        return 0
    fi
    # Printed on stderr: the caller captures stdout as the path.
    echo -e "${RED}✗ botopink binary not found — set BOTOPINK_BIN, build repository/botopink-lang (zig build install) so the enclosing checkout's zig-out/bin/botopink exists, or put botopink on \$PATH${NC}" >&2
    return 1
}

# `$BOTOPINK_BIN`, else the compiler of the ENCLOSING checkout — the nearest
# ancestor holding `repository/botopink-lang/` (a `zig-out/bin/botopink` there
# or nothing: the walk stops at that checkout, so a worktree nested under the
# main checkout never borrows the main checkout's binary), else a botopink-lang
# checkout's own `zig-out`, else `$PATH`.
locateBotopink() {
    if [ -n "${BOTOPINK_BIN:-}" ] && [ -x "$BOTOPINK_BIN" ]; then
        echo "$BOTOPINK_BIN"; return 0
    fi
    local cur; cur=$(pwd)
    local cand
    while [ "$cur" != "/" ]; do
        if [ -d "$cur/repository/botopink-lang" ]; then
            cand="$cur/repository/botopink-lang/zig-out/bin/botopink"
            [ -x "$cand" ] && { echo "$cand"; return 0; }
            break
        fi
        cand="$cur/zig-out/bin/botopink"
        [ -x "$cand" ] && [ -f "$cur/build.zig" ] && { echo "$cand"; return 0; }
        cur=$(dirname "$cur")
    done
    command -v botopink >/dev/null 2>&1 && { command -v botopink; return 0; }
    return 1
}

runStandaloneGate() {
    local root
    root=$(git rev-parse --show-toplevel)
    cd "$root"

    # 1. conflict markers in staged files (regular files only — gitlinks skipped).
    local lt7 eq7 gt7
    lt7=$(printf '<%.0s' {1..7})
    eq7=$(printf '=%.0s' {1..7})
    gt7=$(printf '>%.0s' {1..7})
    local marker_re="${lt7} |${eq7}\$|${gt7} "
    local staged
    staged=$(git diff --cached --name-only --diff-filter=ACM)
    if [ -n "$staged" ]; then
        local hits=""
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            [ -f "$f" ] || continue
            if grep -nE "$marker_re" "$f" 2>/dev/null | head -1 | grep -q .; then
                hits="$hits $f"
            fi
        done <<< "$staged"
        if [ -n "$hits" ]; then
            echo "  Conflict markers in:$hits"
            fail "Conflict markers found in staged files"
        fi
        pass "No conflict markers"
    fi

    # 1a. a snapshot rewrite is never committed: a `*.snap.new` /
    #     `*.snap.md.new` is what a mismatch writes beside its snapshot, and
    #     accepting it is a review, not an add (botopink-lang's gate.sh does the
    #     same). The gate refuses the staged file; `.gitignore` keeps it out of
    #     `git add .`.
    local snapnew
    snapnew=$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.snap(\.md)?\.new$' || true)
    if [ -n "$snapnew" ]; then
        echo "$snapnew" | sed 's/^/  /'
        fail "a *.snap.new / *.snap.md.new is staged — review the snapshot, update the .snap.md, never commit the .new"
    fi
    pass "No staged *.snap.new"

    # 1b. front 23's own greps (`specs/.../23-rakun-ssr-pipeline` § Definition of
    #     done). Three claims that are cheap to check and expensive to lose:
    #     the SSR walker never calls the unescaped renderer, `repository/rakun/`
    #     names no module of onze (decision 77), and `ssr.bp` keeps no tag list
    #     of its own — the void and raw-text sets are front 94's, passed in as
    #     `ElementView` fields.
    #
    #     The greps read CODE, not comments (a `//` line is dropped before the
    #     match), and whole identifiers: `onze` and `jhonstart` as words, the UI
    #     types decision 114 forbids by name (`Element`, `ElementView`,
    #     `Children`, `LayoutProps`, `PageProps`) — never the substring
    #     `Element`, which `xmlElement` carries legitimately.
    local ssr="modules/rakun-app/src/ssr.bp"
    if [ -f "$ssr" ]; then
        if codeLines "$ssr" | grep -q 'renderToString'; then
            fail "ssr.bp calls renderToString — the frozen renderer escapes nothing; a single call is the whole hole"
        fi
        # Decisions 113-115: rakun builds no HTML and names neither the HTML
        # library nor the orchestrator in code — not an import, not a key,
        # not a marker (front 23 step 5, front 22 step 2).
        if codeLines modules/rakun/src/*.bp modules/rakun-app/src/*.bp | grep -q 'from "jhonstart\|from "onze'; then
            fail "modules/rakun/src/ or modules/rakun-app/src/ imports jhonstart or onze (decision 113)"
        fi
        if codeLines modules/rakun/src/*.bp modules/rakun-app/src/*.bp | grep -qiw 'onze'; then
            fail "modules/rakun/src/ or modules/rakun-app/src/ names onze (decisions 113, 115)"
        fi
        if codeLines modules/rakun-app/src/*.bp | grep -qwE 'Element|ElementView|Children|LayoutProps|PageProps|jhonstart'; then
            fail "modules/rakun-app/src/ names a UI type or the HTML library (decision 114)"
        fi
        local voidtag
        for voidtag in area base col embed hr img input link meta source track wbr; do
            if grep -q "\"$voidtag\"" "$ssr"; then
                fail "ssr.bp spells the void tag \"$voidtag\" — the set is front 94's isVoidTag, passed in"
            fi
        done
        pass "front 22/23 greps: no renderToString, no onze or jhonstart, no UI type, no tag list"
    fi
    # The compiler, before any stage that needs it: a miss is a failure here,
    # not a skipped stage.
    local bin
    bin=$(requireBotopink) || exit 1
    pass "Compiler: $bin"

    # 2. botopink test.
    if grep -q '"workspaces"' "$root/botopink.json" 2>/dev/null; then
        # A workspace: one `botopink test` per library member (modules/*/ with a
        # botopink.json), each on its own manifest target. The examples are
        # applications and are built by stage 3.
        local member found=""
        for member in "$root"/modules/*/; do
            [ -f "$member/botopink.json" ] || continue
            found=1
            echo -n "  Testing modules/$(basename "$member") (botopink test)... "
            if ( cd "$member" && "$bin" test ) >/dev/null 2>&1; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${RED}✗${NC}"
                echo
                echo "  Re-run for failure output:  ( cd $member && $bin test )"
                fail "$(basename "$member"): botopink test failed"
            fi
        done
        [ -n "$found" ] || fail "botopink.json is a workspace but no modules/*/ holds a botopink.json"
    else
        if [ -z "$(find src test 2>/dev/null -name '*.bp' ! -name '*.d.bp' | head -1)" ]; then
            echo "  (no .bp sources under src/ or test/ — nothing to test)"
            return 0
        fi
        echo -n "  Testing $(basename "$root") (botopink test)... "
        if ( cd "$root" && "$bin" test ) >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
            echo
            echo "  Re-run for failure output:  ( cd $root && $bin test )"
            fail "$(basename "$root"): botopink test failed"
        fi
    fi

    # 3. every example builds.
    runExamplesGate "$bin"
}

# codeLines <file>… — the files' lines with `//` comments removed (a whole
# `//` / `////` line is dropped; a trailing `// …` is cut), so a grep over the
# result reads code. A string literal is code and stays.
codeLines() {
    sed -E 's://.*$::' "$@"
}

# runExamplesGate <botopink-bin>
#
# Builds every `examples/*/` that has a `botopink.json` (each with its own
# manifest target, into a throwaway --out). An example that does not build
# fails the gate; there is no list of examples allowed to fail.
runExamplesGate() {
    local bin="$1"
    local root
    root=$(git rev-parse --show-toplevel)
    local dir name rel out bad=""
    for dir in "$root"/examples/*/; do
        [ -f "$dir/botopink.json" ] || continue
        name=$(basename "$dir")
        rel="examples/$name"
        out=$(mktemp -d)
        echo -n "  Building $rel (botopink build)... "
        if ( cd "$dir" && "$bin" build --out "$out" ) >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
            bad="$bad\n  $rel does not build — re-run: ( cd $dir && $bin build --out \$(mktemp -d) )"
        fi
        rm -rf "$out"
    done
    if [ -n "$bad" ]; then
        echo -e "$bad"
        fail "$(basename "$root"): examples gate failed"
    fi
}
