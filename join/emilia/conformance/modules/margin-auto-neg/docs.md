# margin-auto-neg

#### `Auto` and `Neg`, on margin

`Auto` is a value on the ladder, so it is on **every** margin direction and gets
the same expansion every multiplier gets. `Neg` is upstream's `-mt-4`, the one
family of utilities with no alternative spelling:

`Neg` carries no `0` and no `Auto` — a negative zero and a negative auto are not
utilities — and its `Half` is `{ 0, 1, 2, 3 }`, answered by the theme's
`spacingNegHalf`: `.Margin.T.Neg.Half.0` is `-mt-0.5`,
`margin-top:calc(var(--spacing) * -0.5)`.
