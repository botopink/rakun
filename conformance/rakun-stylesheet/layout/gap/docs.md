# gap

{src/main.bp}

### Gap — `§ 6.15`

`Gap` is a **top-level section**, not a sub-section of `Flex`, because `gap`,
`column-gap` and `row-gap` separate the items of a grid exactly as they separate
the items of a flex row. It carries front 35's full scale — the thirty
multipliers `0 … 96`, the `Px` step and `Half { 0, 1, 2, 3 }` — on each of
`All`, `X` and `Y`.

`.Gap.All.4` and `.Pad.All.4` carry the same length because both answer
`spacing(4)`. Overriding `--spacing` moves both and rewrites neither rule.

The pre-front-37 `.Flex.Gap.{1,2,4,8}` paths **still compile and still emit
`gap:`** — the same declaration by a narrower name. They used to answer a
hand-written `rem` ladder (`gap-4` was `gap:1rem`, the last of the seven front
54 found); they answer `spacing(n)` now, and a test compares the two spellings
to **each other** so they cannot drift apart again.
