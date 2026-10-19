# Decision 610 — (b), with one rule more: `body:` is the one name of the botopink-body cell, on `Erlang`, `JavaScript` and `Wasm` alone, its two checks written as the cell's rule, and an annotation whose every source is a `body:` is refused.

`backwards` is a `declare fn` with a source per target: erlang and JavaScript call their host's own reverse through a template, and wasm runs `reverseBody`, named by `body:`. `body:` names a bare identifier, a private `fn` with a body in the same module whose parameters and return are the declaration's: `(xs: i32[]) -> i32[]` on both sides. The program prints `3 2 1` on every target.

The other shapes are refused at build. `body:` given a string, a number, a public or bodiless function, or a function of other types is `external-body-not-a-fn` at the argument. A source that names neither a template nor a cell, `.Erlang()`, is `external-source-empty`. An annotation where every source is a `body:` (`.Erlang(body: reverseBody), .JavaScript(body: reverseBody), .Wasm(body: reverseBody)`) is `external-all-bodies`, because a function that runs the botopink body on every target is a plain `fn` with that body. `body:` exists on `Erlang`, `JavaScript` and `Wasm` only, for this per-target split.

Cells in this repository that prove it: none yet. rakun's host functions are erlang-only templates (`modules/rakun/src/runtime.bp`); the library's `body:` sites are re-read in front 165 s10.

[draft/main.bp](draft/main.bp)
