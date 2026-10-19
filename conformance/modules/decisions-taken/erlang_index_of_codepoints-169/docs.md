# Decision 169 — Codepoints on erlang: `indexOf` / `lastIndexOf` answer the codepoint index, as `at` / `slice` / `length` do there, so an

A request path with two characters beyond ASCII, `é` and `☕`. `indexOf("menu")` answers `8` and `lastIndexOf("/")` answers `7` — codepoints, not bytes, on erlang as on the other targets — so the index is handed back: `at(8)` is `m`, `slice(8)` is `menu`, `slice(0, indexOf("☕"))` is `/café/`, and `length` is `12`.

Cells of this repository that prove it: none yet — the rule is std's (`primitives.bp`, `02-erlang` step 6); rakun's routing reads paths through these members.

[draft/main.bp](draft/main.bp)
