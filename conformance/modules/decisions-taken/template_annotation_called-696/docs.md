# Decision 696 — A template function is an annotation only when its signature declares the annotated declaration as its second parameter (578 (1): `syntax q: string`, then `syntax decl: unknown`); called as `` f @`…` `` it is `template-annotation-only`, and a template without that parameter at `#[f @`…`]` is `template-annotation-without-decl`.

The example declares two templates whose signatures say which form each takes. `entityQuery`'s
second parameter is `syntax decl: unknown`, the annotated declaration, so it is an annotation
template: written `#[entityQuery @`select * from users where id = ${id}`]` on the repository
method `byId`, it records the statement on the method as typed meta, and `main` reads it back
through `compiler.typeInfo(Users)`'s methods. `count` takes the text alone, so it is called as an
expression, `count @`users``, and answers the code it builds.

The two uses are two functions; neither form reaches the other. `val s = entityQuery @`select 1`;`
is refused at the call as `template-annotation-only` — the template needs a declaration the call
cannot give it — and `#[count @`users`]` on a method is refused as
`template-annotation-without-decl`, `count` declaring no parameter to receive the method.

Proving cells: none in this repository yet; rakun-data's `#[query]` is still an ordinary decorator
over a string (`modules/rakun-data/src/sql/query.bp`). The cells come with `machine-1/144` B-18 and
rakun front 150.

[draft/main.bp](draft/main.bp)
