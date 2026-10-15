#!/usr/bin/env bash
# repository-stages.sh — the stages of the pre-commit gate only rakun has.
#
# `scripts/git-hooks/lib/runner-standalone.sh` is one text in every library
# repository; what is rakun's own lives here. The runner sources this file in a
# child bash process (stage 3, `runRepositoryStagesGate`), from the repository
# root, after it has sourced itself — so `fail`, `pass`, `gate_root` and
# `$BOTOPINK_BIN` are available. This file can only ADD a red: its exit status
# is all the runner reads (non-zero fails the gate), and nothing it defines or
# sets reaches the shell that runs the shared stages. CI runs it too (the
# workflow's hook-stages step).
#
# Front 23's own greps (`specs/.../23-rakun-ssr-pipeline` § Definition of
# done). Three claims that are cheap to check and expensive to lose: the SSR
# walker never calls the unescaped renderer, `repository/rakun/` names no
# module of rakun-ssr (decision 77), and `ssr.bp` keeps no tag list of its own — the
# void and raw-text sets are front 94's, passed in as `ElementView` fields.
#
# The greps read CODE, not comments (a `//` line is dropped before the match),
# and whole identifiers: `rakun-ssr` and `rakun-bpp` as words, the UI types decision
# 114 forbids by name (`Element`, `ElementView`, `Children`, `LayoutProps`,
# `PageProps`) — never the substring `Element`, which `xmlElement` carries
# legitimately.

# codeLines <file>… — the files' lines with `//` comments removed (a whole
# `//` / `////` line is dropped; a trailing `// …` is cut), so a grep over the
# result reads code. A string literal is code and stays.
codeLines() {
    sed -E 's://.*$::' "$@"
}

# A match is read with `grep … >/dev/null`, never `grep -q`: under `pipefail` a
# `grep -q` that exits at its first match can leave `sed` writing to a closed
# pipe, and the pipeline's status would then say "no match".

ssr="modules/rakun-app/src/ssr.bp"
[ -f "$ssr" ] || fail "$ssr is missing — the front 22/23 greps have nothing to read"

if codeLines "$ssr" | grep 'renderToString' >/dev/null; then
    fail "ssr.bp calls renderToString — the frozen renderer escapes nothing; a single call is the whole hole"
fi
# Decisions 113-115: rakun builds no HTML and names neither the HTML library
# nor the orchestrator in code — not an import, not a key, not a marker (front
# 23 step 5, front 22 step 2).
# `version_set.bp` is the one table that pins every package of the workspace (front 165 s2,
# question 165-a): it names `rakun-bpp` and `rakun-ssr` as data rows and imports nothing, so
# the name greps skip that one file; the import grep keeps reading it.
nameFiles=$(ls modules/rakun/src/*.bp | grep -v '/version_set\.bp$') || true
if codeLines modules/rakun/src/*.bp modules/rakun-app/src/*.bp | grep 'from "rakun-bpp\|from "rakun-ssr' >/dev/null; then
    fail "modules/rakun/src/ or modules/rakun-app/src/ imports rakun-bpp or rakun-ssr (decision 113)"
fi
if codeLines $nameFiles modules/rakun-app/src/*.bp | grep -iw 'rakun-ssr' >/dev/null; then
    fail "modules/rakun/src/ or modules/rakun-app/src/ names rakun-ssr (decisions 113, 115)"
fi
if codeLines modules/rakun-app/src/*.bp | grep -wE 'Element|ElementView|Children|LayoutProps|PageProps|rakun-bpp' >/dev/null; then
    fail "modules/rakun-app/src/ names a UI type or the HTML library (decision 114)"
fi
for voidtag in area base col embed hr img input link meta source track wbr; do
    if grep -q "\"$voidtag\"" "$ssr"; then
        fail "ssr.bp spells the void tag \"$voidtag\" — the set is front 94's isVoidTag, passed in"
    fi
done
pass "front 22/23 greps: no renderToString, no rakun-ssr or rakun-bpp, no UI type, no tag list"

# Decision 548: the conformance reference links its code, never copies it — every
# `{<path>}` of a `conformance/**/docs.md` names a file relative to that docs.md,
# every cell is linked by its feature's docs.md, and no ```bp fence remains.
if scripts/check-doc-links.sh; then
    pass "conformance docs: every {<path>} link names a file"
else
    fail "conformance docs: a link names no file (scripts/check-doc-links.sh)"
fi
