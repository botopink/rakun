# Decision 331 — Every `comptime` runs at compile time, now, independent of the target.

The example has two `comptime` blocks, and both run while the program is compiled. `seatLimit`'s
block loops over `[1, 2, 3]` and calls the ordinary function `add` on each element; the loop and
the calls run on the comptime runtime, not on the target being built, and the function the program
holds is `return 6;`. `beans` is rakun's registry: the block reads the catalogue of the
`#[service]` and `#[repository]` declarations and folds it into a `Dict` with `rkAddBean`, and that
`Dict` is lifted into the program as a value.

Because neither block runs on the target, one source answers the same everywhere: `main` prints
`6 3` whatever the program is built for, and nothing is refused for holding a loop or a call
inside `comptime`.

Proving cells: `conformance/rakun/container/resolve`, `conformance/rakun/container/managed` and
`conformance/rakun/web/usage`, whose `beans()` builds the registry in a `comptime` block over the
catalogue.

[draft/main.bp](draft/main.bp)
