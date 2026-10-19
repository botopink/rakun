# Decision 320 — A string index counts codepoints on every target — the same value everywhere.

The example cuts a request path the way a rakun handler does, by index. `"cafe\u{301}"` writes the
accent as its own combining codepoint: `length` is `5` and `at(4)` is the combining mark — the index
counts codepoints, not the one grapheme a reader sees. `"👍".length` is `1`. On the path
`/menu/café/👍` (with a precomposed `é`), `length` is `12`, `indexOf("é")` is `9` and
`lastIndexOf("/")` is `10`; `lastSegment` slices after that slash and answers `👍`, and
`slice(6, 10)` is `café`. The body of the response built from the segment has length `1`. Every
number is the same on erlang, beam, commonJS and wasm: none of them counts grapheme clusters, and
commonJS does not count UTF-16 units.

Proving cells: none in this repository; the indices are std's and the backends', proved by
botopink-lang's cells (`run/string_index_of_codepoints`).

[draft/main.bp](draft/main.bp)
