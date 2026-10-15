# Typography

> Package: [`rakun-stylesheet`](../docs.md) · index: [`../../docs.md`](../../docs.md)

## Text, Font and List — `§ 9`

Thirty-two property groups. The listing below is by group; every leaf is in
[`tokens.bp`](../../../modules/rakun-stylesheet/src/tokens.bp).

**A size is TWO declarations.** Upstream's `text-lg` sets a font-size AND the
line-height paired with it, and both are theme references:

{text-size/src/main.bp}

Thirteen sizes: `Xs Sm Base Lg Xl X2xl X3xl X4xl X5xl X6xl X7xl X8xl X9xl`.
The values are front 54's `defaultTheme()`, so a project that overrides
`--text-lg` moves every `text-lg` rule and no class name changes.

{font-family-weight/src/main.bp}

Nine weights: `Thin Extralight Light Normal Medium Semibold Bold Extrabold
Black`, `100` through `900`. The weights stay LITERAL — that is the form the
reference prints — while the families are references, and the three stacks live
in `typographyEntries()`, copied from upstream v4's `theme.css` (the reference
prints none).

{font-smoothing-style/src/main.bp}

Nine stretch values (`UltraCondensed ExtraCondensed Condensed SemiCondensed
Normal SemiExpanded Expanded ExtraExpanded UltraExpanded`) and nine numeric
variants (`Normal Ordinal SlashedZero Lining Oldstyle Proportional Tabular
DiagonalFractions StackedFractions`).

**Tracking and leading** are references too; `leading-none` is the one leaf the
reference prints as a literal:

{text-tracking-leading/src/main.bp}

**The decoration family.** The line is the LONGHAND, which is what lets it
compose with a style instead of overwriting it:

{text-decoration/src/main.bp}

`Decoration.Color` is the SAME 26 x 11 grid `Color` and `Bg.Color` carry, through
the same `paletteVar`, so a decoration colour and a text colour cannot drift.

**Alignment, transform, overflow and wrap:**

{text-align-transform/src/main.bp}

`Clamp` runs `1` to `6` plus `None`, and `None` is the four-declaration RESET
rather than the absence of a token.

**Whitespace, breaking, hyphens, indent, align, tab, content:**

{text-whitespace-break/src/main.bp}

- **`Break` and `OverflowWrap` are two sections, not one.** Upstream's `break-*`
  and `wrap-*` overlap in EFFECT and not in PROPERTY — `break-words` is an
  `overflow-wrap` although it is spelled `break-` — and merging them would lose
  `wrap-anywhere`, which has no `break-*` spelling at all.
- **`Text.Indent` never resolves a length.** It answers front 54's
  `spacing(n)`, the same function `.Pad.All.8` answers, so the two agree by
  construction.
- **`.Text.Bold` and `.Text.Italic` are rakun-stylesheet's own leaves**, not
  transcriptions of a Tailwind utility; `font-weight:bold` is what they emitted
  before `§ 9` landed and what they emit now.

## List — `§ 9.12`–`§ 9.14`

{list-style/src/main.bp}

Top-level, because `list-style-*` applies to the list and not to its text.
