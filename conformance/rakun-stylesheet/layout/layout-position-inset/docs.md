# layout-position-inset

{src/main.bp}

#### Position and inset

`Inset` carries the **nine directions** `Pad` and `Margin` carry — `All`, `X`,
`Y`, `T`, `R`, `B`, `L` and the logical pair `S`/`E` — over the **same scale**,
answering the **same** `spacing(n)` / `spacingHalf(n)`. That is not a
coincidence to be maintained: `.Layout.Inset.T.4` and `.Pad.T.4` differ only in
the property name, and a test asserts the two length strings are equal.

`inset` is a real CSS shorthand, so `All` is one declaration. `left`/`right` and
`top`/`bottom` have none, so `X` and `Y` expand to two — which is how `§ 5.17`
prints `inset-x-0`.
