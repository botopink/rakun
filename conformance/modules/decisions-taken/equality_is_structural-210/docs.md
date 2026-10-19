# Decision 210 — `==` is structural on every target: records, tuples, lists and enum variants compare by value, recursively; two values o

The example compares values that are built apart. `Response.ok("hello")` and
`Response(status: 200, body: "hello")` are two rakun responses with the same fields, and `==`
answers `true`; `!=` against `Response.notFound()` is its negation, `true`. `Route` holds an enum
variant and a list of strings: `r1` and `r2` are equal because every field is, recursively, and `r3`
differs only in its `HttpMethod` variant, so `r1 == r3` is `false`. The last line compares a tuple
holding a record and lists of records, `true`, `true`, `false`. No line compares references: the
answers are the same on erlang, where a value is one term, and on the targets where the compiler
writes an equality function per type.

Proving cells: none in this repository; equality is the compiler's, proved by botopink-lang's
four-target cells.

[draft/main.bp](draft/main.bp)
