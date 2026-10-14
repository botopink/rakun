# font-family-weight

Thirteen sizes: `Xs Sm Base Lg Xl X2xl X3xl X4xl X5xl X6xl X7xl X8xl X9xl`.
The values are front 54's `defaultTheme()`, so a project that overrides
`--text-lg` moves every `text-lg` rule and no class name changes.

Nine weights: `Thin Extralight Light Normal Medium Semibold Bold Extrabold
Black`, `100` through `900`. The weights stay LITERAL — that is the form the
reference prints — while the families are references, and the three stacks live
in `typographyEntries()`, copied from upstream v4's `theme.css` (the reference
prints none).
