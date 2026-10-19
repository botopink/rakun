# Decision 431 — `@Result<T, E>` is botopink's checked error — Java's `throws`, Rust's `?` —, and an error that does not arrive as a `@Result` is converted at one boundary: the host binding (`result: true`) or an explicit `attempt`.

The example reads an id from a request path in three layers. `hostInt` is an erlang host call,
`binary_to_integer`, which raises on a numeral it cannot read; its binding says `result: true`, so
every way the host fails arrives as `Error(HostError(…))` and the declared return says so. `idOf`
handles that error on the spot with `try … catch` and throws its own `BadId`, and throws it again for
an id below one: `throw` is legal because `Result<i64, BadId>` is in its signature. `lookup` writes
`try idOf(raw)` — the propagation is written at the call, never implied — and `answer`, which
returns a plain `Response`, handles the `Result` with `case`. So `"42"` answers `item 42`, `"x7"`
answers `bad id: x7` and `"0"` a `400`. A `throw` or a propagating `try` in a function with no
`Result` in its return would be refused at it (`effect-try-without-fallible-channel`).

The last call is a crash, not an error: `plugin("boom")` panics, which no signature mentions, and
only `attempt` contains it, as a `Failure` of kind `panic` — the program prints
`panic: plugin crashed`.

Proving cells: none in this repository yet; the mechanism is the compiler's (01-checker step 42),
proved by botopink-lang's cells, and rakun's handlers that answer `Result` come with front 150's
Conformance step.

[draft/main.bp](draft/main.bp)
