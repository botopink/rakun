# spacing-scale

{src/main.bp}

#### The scale

Every direction answers the same 35 leaves: the thirty multipliers
`0 1 2 3 4 5 6 7 8 9 10 11 12 14 16 20 24 28 32 36 40 44 48 52 56 60 64 72 80 96`,
the pixel step `Px`, and `Half { 0, 1, 2, 3 }`.

`0.5` cannot be an enum leaf — a numeric leaf is a run of digits — so `Half.1`
reads "one and a half" and `Half { 0, 1, 2, 3 }` covers `0.5`, `1.5`, `2.5` and
`3.5`. **A spacing value is never resolved here**: every leaf answers
`spacing(n)` or `spacingHalf(n)`, so `--spacing` stays the one place the length
is decided (§ Spacing — `spacing(n)`).
