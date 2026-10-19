# Decision 391 — The snapshot engine is a library of its own — `snap`, `botopink/snap` at `repository/snap` (326's rule) — and std provides only the general primitives it is written over.

The example renders a rakun-bpp component and snapshots it in a `test` block. `assertHtml` is
rakun-bpp's helper — the `<lib>-test` half that became the package's `testing/` module — and it
writes nothing itself: it calls `snap`'s `assertAs` with the subject `html`, so the snapshot lands at
`__snapshots__/<suite>/<slug>.snap` beside this file, the suite and the slug taken from the test's
name and the source location `comptime compiler.src()` hands it. A first run records the file; a run
whose output differs writes `<path>.new` beside it and fails, and a person renaming `.new` accepts
the change — there is no update flag. std provides only what that engine is written over (the
location, `io/fs`, `path`); `testing.snapshots` is gone from std, so no rakun package snapshots any
other way. `main` prints the same markup on one line and one tag per line, the two texts the
helpers snapshot.

Proving cells: none in this repository yet; the engine's cells are `snap`'s, and rakun-bpp's helpers
are exercised by its own tests until front 150's Conformance step writes cells for them.

[draft/main.bp](draft/main.bp)
