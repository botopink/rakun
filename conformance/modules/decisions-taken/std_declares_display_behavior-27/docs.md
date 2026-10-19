# Decision 27 — Who declares `behavior Display`?

The example has two values that say how they read, both through the one `behavior Display` std
declares. `RouteLine` is a line of a route listing as rakun shows one: it writes
`implement Display` with no import — the behavior is ambient, beside `string` and `Result` — and its
`display` answers `GET /api/hello/:name -> GreetingController.hello`. `terminal.print(hello)` prints
exactly that: `print` asks a value for its own `display` before it falls back to the per-type
formatter, so the second line is `true`. The third line prints a `Dict` of hit counts as
`Dict("/api/hello": 3, "/api/bye": 1)`: std's `Dict` implements the same declaration, the string keys
quoted, the numbers in their own text. There is one `Display`, in std, and every target's formatter
reads it; neither rakun nor the program declares a second one.

Proving cells: none in this repository yet; the behavior's own cells are botopink-lang's, and rakun's
listings that implement it come with front 150's Conformance step (decision 465).

[draft/main.bp](draft/main.bp)
