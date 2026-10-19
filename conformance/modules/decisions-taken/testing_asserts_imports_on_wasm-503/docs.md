# Decision 503 — `testing.asserts` imports on wasm, its API unchanged; `matches` waits on std's regex there, a located refusal until then. Amends 146.

The example checks a rakun response with std's `testing.asserts`, the module every target imports
with one API. `equals` compares the status, `deepEquals` the whole `Response` record against one
built by hand, `contains` a body's text: each answers `Ok`, printed `ok`. `throws` runs a body that
unwraps a missing element — an abort — and answers `Ok` because the body did fail; it is written over
`attempt`, so it needs no host `try/catch` and imports on wasm as on the other targets, and
`deepEquals` has a botopink body there. The one assertion the program leaves out is `matches`: on
wasm it waits on std's regex, and a call that reaches it there is a located refusal at that call,
never a refusal of the import.

Proving cells: none in this repository; the module is std's (144 B-25), proved by botopink-lang's cells.

[draft/main.bp](draft/main.bp)
