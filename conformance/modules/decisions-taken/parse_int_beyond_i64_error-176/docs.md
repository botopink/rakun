# Decision 176 — † `string.parseInt()` of an integer beyond the `i64` range (−2^63 … 2^63 − 1, 319) is `Error` on every target

The example reads a path parameter as an id, as a rakun handler does with `req.param("id")`.
`"9223372036854775807"` is the largest `i64`, so `parseInt()` answers `Ok` and the handler answers
`item 9223372036854775807`. One more, `"9223372036854775808"`, is outside the range: `parseInt()`
answers `Error` and the handler answers `400`. The same at the bottom of the range: the smallest
`i64` reads, the next integer below it is a `400`. No target wraps the numeral, rounds it through a
float or answers a `bigint` in its place.

Proving cells: none in this repository; the reader is std's (`02/97`), proved by botopink-lang's cells.

[draft/main.bp](draft/main.bp)
