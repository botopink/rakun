# Decision 264 — Integer overflow is a program error on every target: `+`, `-`, `*`, unary `-` and the compound assignments of every inte

The example adds one to a counter. `next(41)` answers `42`. `next(2147483647)` adds one to the
largest `i32`: the result does not fit the declared type, so the addition aborts the program — it
does not wrap to a negative number and does not answer a wider one. `attempt` contains the abort as
a `Failure` whose kind is `panic`, so the program prints `panic`, and a rakun handler that ran the
same code would answer a `500` (the last line) rather than a wrong count. The same happens on every
target, each one checking the operation against the type's range.

Proving cells: none in this repository; the check is the compiler's, proved by botopink-lang's cells.

[draft/main.bp](draft/main.bp)
