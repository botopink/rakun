# grid

### Grid — `§ 6.8`–`§ 6.14`

`display:grid` is `Layout`'s (`.Layout.Grid`) and used to be all emilia had:
there was no template, no span, no start, no end, no flow and no implicit
track, so nothing could be put inside the box it declares.

A template is a **function of the leaf**, not a lookup: `gridRepeat(n)` builds
`repeat(N, minmax(0, 1fr))` — one space after each comma — and it is the only
place that text is spelled. The `minmax(0, 1fr)` inside it is `gridFr()`, the
same string the implicit `fr` tracks read, so the two cannot drift.

`Cols`, `Rows` and `Span` run **1 … 12**; `Start` and `End` run **1 … 13**,
because a twelve-column grid has thirteen lines.

**Nothing in `Grid` is a length.** A column count, a span and a line number are
integers, so no leaf reaches `spacing(n)` and none spells a `rem`.

**Not declared:** every arbitrary-value form (`grid-cols-[200px_1fr]`,
`col-start-[7]`), which belongs to the escape-hatch front.
