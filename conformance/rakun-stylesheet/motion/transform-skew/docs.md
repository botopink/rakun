# transform-skew

{src/main.bp}

#### Skew — upstream v4's variable and chain

`§ 16.6`'s "Propriedade CSS" column says `skew-x: 3deg`. That is not a
registered CSS property. Upstream writes the axis into a variable and a chain
of five variables into `transform`, and so does rakun-stylesheet:

An unset variable is nothing (the empty fallback), so **two skews in one rule
compose**. Each skew class registers the chain's five variables with
`@property` (no initial value).
