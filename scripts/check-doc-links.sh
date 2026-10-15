#!/usr/bin/env bash
# check-doc-links.sh — every reference under conformance/ links its code, and
# every link names a file that exists (front 165).
#
# Code inside a `docs.md` is never copied, only linked (decision 548): a path
# in braces, relative to the directory of the `docs.md` that holds it, names the
# file to show — `{src/main.bp}` in a cell's `docs.md`, `{<cell>/src/main.bp}`
# in a feature's (`conformance/<package>/<feature>/docs.md`). This script fails
# when, in any `conformance/**/docs.md`:
#   - a `{<path>}` link names no file;
#   - a markdown link `[…](<relative path>)` names nothing on disk;
#   - a ```bp fence or an `<!-- example: … -->` marker remains (the old forms);
#   - a cell (a directory holding `src/main.bp`) has a `docs.md` that does not
#     link `{src/main.bp}`, or is linked by no other `docs.md` (its feature's).
#
# Run from the repository root; `scripts/git-hooks/repository-stages.sh` runs it.
# Exit 0 = every link resolves.

set -uo pipefail
root="${1:-conformance}"
status=0
bad() { echo "check-doc-links: $*" >&2; status=1; }

[ -d "$root" ] || exit 0

linked_cells=""
while IFS= read -r doc; do
    dir="$(dirname "$doc")"
    # Lines outside fences, with inline code spans removed.
    prose="$(awk '/^```/{f=!f; next} !f' "$doc" | sed -E 's/`[^`]*`//g')"
    if grep -n '^```bp' "$doc" >/dev/null; then
        bad "$doc: a \`\`\`bp fence — link the cell's code as {<path>} instead"
    fi
    if grep -n '<!-- example:' "$doc" >/dev/null; then
        bad "$doc: an <!-- example: … --> marker — write {<cell>/src/main.bp} in the feature's docs.md"
    fi
    while IFS= read -r link; do
        [ -n "$link" ] || continue
        path="${link#\{}"; path="${path%\}}"
        if [ -f "$dir/$path" ]; then
            case "$path" in
                src/main.bp) ;;
                */src/main.bp) linked_cells="$linked_cells
$(cd "$dir/$(dirname "$(dirname "$path")")" && pwd)" ;;
            esac
        else
            bad "$doc: {$path} names no file"
        fi
    done < <(printf '%s\n' "$prose" | grep -oE '\{[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+\}')
    while IFS= read -r target; do
        [ -n "$target" ] || continue
        target="${target%%#*}"
        [ -n "$target" ] || continue
        [ -e "$dir/$target" ] || bad "$doc: link ($target) names nothing on disk"
    done < <(printf '%s\n' "$prose" | grep -oE '\]\([^)[:space:]]+\)' | sed -E 's/^\]\((.*)\)$/\1/' | grep -vE '^(https?:|mailto:|#)')
done < <(find "$root" -name docs.md -not -path '*/.botopinkbuild/*' -not -path '*/deps/*' | sort)

while IFS= read -r main; do
    cell="$(dirname "$(dirname "$main")")"
    if [ ! -f "$cell/docs.md" ] || ! grep -F '{src/main.bp}' "$cell/docs.md" >/dev/null; then
        bad "$cell/docs.md does not link {src/main.bp}"
    fi
    abs="$(cd "$cell" && pwd)"
    printf '%s\n' "$linked_cells" | grep -Fx "$abs" >/dev/null || bad "$cell: no docs.md (its feature's) links {$(basename "$cell")/src/main.bp}"
done < <(find "$root" -path '*/src/main.bp' -not -path '*/deps/*' -not -path '*/.botopinkbuild/*' | sort)

exit $status
