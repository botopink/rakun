# Decision 191 — jhonstart's templates accept in `{expr}` a closed list: a `string`; a number of any numeric type and a `bool`, each writ

The example renders one summary with every kind of value a markup hole takes. `Summary` writes
`${name}` (a `string`), `${count}` (an `i32`), `${ratio}` (an `f64`) and `${active}` (a `bool`)
inside the same `<p>`: each number and the `bool` is written as its `toString()` text, so the line
reads `3 items, 0.5 full, active: true` on every target. `${Badge("featured")}` is a component the
template renders in place, `${badges}` a list of such components rendered one after the other, and
`${extra}` a value typed `Node` — the name of that whole set, so a helper that may answer any of
them declares `Node` and the hole accepts it.

What the set leaves out is refused at build, at the hole: had `Summary` written `${cart}` with
`cart` a record, or `${maybeName}` with a `?string`, or a function, or a component answering
something other than an `Element`, the program would not build — the template takes no value it
would have to guess how to print.

Proving cells: `conformance/rakun-bpp/html-dsl/html_dsl_hole` (a `string` hole expanded into the
builder pipeline). No cell of this repository proves the numeric, `bool`, component and list holes
or the refusal yet; they come with front 118 step 2 and the rakun-bpp Conformance step (465).

[draft/main.bp](draft/main.bp)
