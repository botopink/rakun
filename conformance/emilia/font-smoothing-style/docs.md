# font-smoothing-style

Nine weights: `Thin Extralight Light Normal Medium Semibold Bold Extrabold
Black`, `100` through `900`. The weights stay LITERAL — that is the form the
reference prints — while the families are references, and the three stacks live
in `typographyEntries()`, copied from upstream v4's `theme.css` (the reference
prints none).

Nine stretch values (`UltraCondensed ExtraCondensed Condensed SemiCondensed
Normal SemiExpanded Expanded ExtraExpanded UltraExpanded`) and nine numeric
variants (`Normal Ordinal SlashedZero Lining Oldstyle Proportional Tabular
DiagonalFractions StackedFractions`).

**Tracking and leading** are references too; `leading-none` is the one leaf the
reference prints as a literal:
