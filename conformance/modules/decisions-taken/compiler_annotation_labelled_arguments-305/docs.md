# Decision 305 — The compiler's own annotations speak botopink:

The example uses the compiler's own annotations in a rakun controller, every labelled argument
written `label: value`. `#[compiler.beamMemory(.Ets)]` (774) keeps the per-name hit count in the one-row ETS table
of a module `var`, and `hits = hits.bump(name, 1)` is an atomic read-modify-write on the BEAM (547 (ii)); 547
removed `keyed: true`. `first` is a host binding with one source per target: on erlang the host code
`string:slice($0, 0, 1)` with `inline: true`, on commonJS a JavaScript expression, and on wasm
`body: firstBody` — a reference to the botopink function below, checked where it is written, not
a `"fn:firstBody"` text. `root` gives wasm `op: "f64.sqrt"`, the opcode's name as a string the
compiler checks against its table. The unlabelled string of each `.Erlang` and `.JavaScript` stays
host code, its `$0` the first argument.

`main` prints `r 4.0`. Writing any of these arguments as `inline = true` is a
parse error at the `=`, naming `inline:`; the formatter prints `:` everywhere.

Proving cells: none in this repository; rakun's host bindings (`runtime.bp`, `context.bp`) are
written this way today, and the compiler's cells of the form are botopink-lang's (`01-checker` s27,
`16-formatter` s10).

[draft/main.bp](draft/main.bp)
