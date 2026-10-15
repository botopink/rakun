# text-size

{src/main.bp}

### Text, Font and List — `§ 9`

Thirty-two property groups. The listing below is by group; every leaf is in
[`tokens.bp`](../../../../modules/rakun-stylesheet/src/tokens.bp).

**A size is TWO declarations.** Upstream's `text-lg` sets a font-size AND the
line-height paired with it, and both are theme references:

Thirteen sizes: `Xs Sm Base Lg Xl X2xl X3xl X4xl X5xl X6xl X7xl X8xl X9xl`.
The values are front 54's `defaultTheme()`, so a project that overrides
`--text-lg` moves every `text-lg` rule and no class name changes.
