# Decision 311 — A method with no body in a `type` is only a host binding; a declared-only method is a `behavior`'s; a template can be an annotation.

The program shows the three forms side by side, around rakun's `Response`. `Clock.now` is a method with no body in a `type`, and it has exactly one meaning: a host binding, its Erlang and JavaScript sources given by `#[compiler.external(…)]`; the program prints `12:00`. `Users.find` is declared without a body in a `behavior`, and `MemoryUsers` implements it — the in-memory repository answers `Response.ok("ana")` for id 1 and `Response.notFound()` otherwise, so the program prints `ana` and `404`.

`sql` is a template function — its first parameter is the text, captured unevaluated — and `#[sql @`…`]` on `lookup` is that template call written as an annotation: the same function also receives the annotated declaration. The `${id}` hole names `lookup`'s own parameter, read in the annotated function's scope. What the template recorded is read at build with `compiler.typeInfo(lookup).meta(Statement)`: the statement text and its one parameter, `id`.

A `declare fn` in a `type` with no binding is refused at every call; no decorator supplies a body. `#[sql(…)]`, the call form, on a template function is a located error naming `#[sql "…"]`.

Cells of this repository that prove it: none yet. rakun-data's `#[query("…")]` (`modules/rakun-data/src/sql/query.bp`) is still an ordinary decorator over a method with a body; its template-annotation form is rakun 08 step 7's.

[draft/main.bp](draft/main.bp)
