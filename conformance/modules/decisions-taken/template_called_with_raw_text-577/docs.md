# Decision 577 — A template is called one way: its name before a template text `` @`…` ``, raw.

The example calls templates the one way they are called: the template's name before a template
text. `html @`…`` builds a card from a text that spans lines and holds its bytes as written — the
`\n` inside that `<p>` is the two characters backslash and `n`, not a line break, and the
backtick in the label is written `` \` ``, the text's one escape. `${title}` is not interpolated by
the language: it is `html`'s own hole syntax, which the template reads from its raw text and
splices as code typed in `Card`'s scope.

`sql` is a template declared in this module with the shape a template has: its first parameter
`syntax q: string` takes the text, and a second `syntax decl: unknown` makes it usable as an
annotation too. `#[sql @`select * from posts where id = ${id}`]` on `findPost` is that call written
as an annotation; it records the statement as typed meta, which `main` reads back with
`compiler.typeInfo`.

Every other spelling is refused as `syntax-call-outside-syntax`: `html "…"`, `html """…"""`,
`html("…")`, `#[sql("…")]`, and `html` taken as a value (`val f = html;`). A template — a function whose first parameter is `syntax q: string` — declared with any other
parameters is refused at its declaration (`template-signature`).

Proving cells: `conformance/rakun-bpp/html-dsl/html_dsl_hole` and `html_dsl_prelude` call `html`
with a template text; the annotation form and the refusals come with 144 B-136 and front 165 s10.

[draft/main.bp](draft/main.bp)
