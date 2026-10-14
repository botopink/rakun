# spacing-functions

### Spacing — `spacing(n)`

| Function | What it answers |
| --- | --- |
| `spacing(n) -> string` | `calc(var(--spacing) * n)`; `spacing(0)` is `0` |
| `spacingHalf(n) -> string` | `calc(var(--spacing) * n.5)`; `n` is never negative (a negative `n` aborts) |
| `spacingNegHalf(n) -> string` | `calc(var(--spacing) * -n.5)`; `spacingNegHalf(0)` is the `-0.5` rung |

emilia **never resolves a spacing value**. Every spacing utility is a multiplier
of `var(--spacing)`, resolved by the browser, so the same token list renders
differently under a theme whose `--spacing` is `4px` and one whose `--spacing`
is `0.25rem`. Emitting `1rem` instead would make that override silently
ineffective.

A negative whole step needs no second function (`spacing(-4)`). A negative HALF
step does: `spacingHalf` takes the whole part as an `i32`, and an `i32` has no
negative zero, so `-0.5` could not be spelled through it — the sign lives in
`spacingNegHalf`'s name instead. `spacing` takes an `i32`, not an `f64`, so the
emitted string never depends on a backend's float formatting; the fractional
steps are a closed set that the two half functions cover exactly.
