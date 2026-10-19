# Decision 359 — A spread copies a record's fields — in a record's construction and on a tag alike, typed.

rakun's `Response` is a record, so a changed response is a new one built from the old. `Response(..base, status: 201)` copies every field of `base` and then sets `status`, so `created` is `201` with `base`'s body, `hello`. `Response(..missing, ..base, status: 404)` mixes two spreads and a labelled field, applied left to right with the later winning: `base`'s fields overwrite `missing`'s, and the explicit `status` overwrites both — `404` with the body `hello`. `base` itself still answers `200`: the spread evaluates its source once and builds a new record.

A spread of a record of another type is refused at the `..`, naming both types; a field without a default that no spread or label supplies is an error at the call; a plain function call takes no spread. A component tag spreads its props the same way — `<Card {..p} featured />` is `Card(..p, featured: true)`, into the component's record parameter. The spread is spelled `..` (decision 529, which amends this row's `...`); `...` is only the inclusive range.

Cells of this repository that prove it: none yet. rakun's sources rebuild records field by field (`modules/rakun-style/src/theme.bp`, `put`); the tag spread is `08-bpp/118` step 1's.

[draft/main.bp](draft/main.bp)
