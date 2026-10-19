# Decision 177 — † `fs.glob`, one rule on both targets: `*` and `**` do not match a name that starts with `.` unless the pattern writes t

The example lays out an app directory the way rakun-app's i18n loader reads it, then lists it with `**/dictionaries/*.bp`, the loader's own pattern (`modules/rakun-app/src/i18n.bp`). `seed` writes three dictionaries: `en/dictionaries/home.bp`, a draft `en/dictionaries/.draft.bp`, and `.cache/dictionaries/old.bp` inside a hidden directory.

Neither `**` nor `*` matches a name that starts with `.`, so the first listing is `["en/dictionaries/home.bp"]`: the draft and the whole `.cache` tree are skipped. A pattern that writes the dot matches the dotted name. `**/dictionaries/.*.bp` lists `["en/dictionaries/.draft.bp"]`, and `.cache/dictionaries/*.bp` lists `[".cache/dictionaries/old.bp"]`. The walk does not go down through a link to a directory either. The rule and its answers are the same on commonJS and erlang.

Cells in this repository that prove it: none yet. rakun-app's i18n loader and rakun-ssr's content collections (`content.collections.glob`) list through `fs.glob`, and their cells come with front 165 s7, the workspace's Conformance step.

[draft/main.bp](draft/main.bp)
