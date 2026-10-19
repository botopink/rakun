# Decision 616 — The parameter modifier `expr` is renamed `syntax`: a parameter marked `syntax` receives the code as it was written — a declaration, an argument expression, a lambda — and `comptime` one receives a value known at build.

The example is a decorator with the three arrivals a parameter can have. `#[guarded("/admin", { ->
Response.withStatus(403, "forbidden") })]` annotates rakun's `AdminController`. `decl` is marked
`syntax`: it receives the annotated declaration as written. `deny` is `syntax` too: it receives the
lambda as written, typed against `fn() -> Response` at the argument, and the decorator reads its
text with `compiler.text(deny)` at build without running it. `prefix` is `comptime`: it receives the
value `"/admin"`, known at build.

The executor then hands all three on to the running program — the prefix and the text as literals,
the lambda as the code it is. `main` prints `/admin -> { -> Response.withStatus(403, "forbidden") } =
403`. The word is `syntax` in every position:
on a declaration (`syntax decl`), an argument expression and a lambda alike; the old `expr` spelling
is gone.

Proving cells: none in this repository uses a `syntax` parameter other than `decl`; every decorator
of rakun writes `syntax decl: unknown` today (`modules/rakun/src/decorators.bp`), shown by
`conformance/rakun/web/usage`.

[draft/main.bp](draft/main.bp)
