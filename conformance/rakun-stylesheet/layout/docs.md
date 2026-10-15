# Layout

> Package: [`rakun-stylesheet`](../docs.md) · index: [`../../docs.md`](../../docs.md)

## Layout — `§ 5`

`Layout` is two things at once. The **eleven display values are the section's
own leaves**, so `.Layout.Flex` is a display value and not a flex container:

{layout-display/src/main.bp}

`hidden` is the one row whose Tailwind name is not its CSS value: `.Layout.Hidden`
is `display:none`. The flex and grid CONTAINER properties — direction, wrap,
alignment, `gap` — are `Token.Flex`'s, not `Layout`'s.

Everything else in `§ 5` is a **sub-section** beside those leaves.

### Position and inset

{layout-position-inset/src/main.bp}

`Inset` carries the **nine directions** `Pad` and `Margin` carry — `All`, `X`,
`Y`, `T`, `R`, `B`, `L` and the logical pair `S`/`E` — over the **same scale**,
answering the **same** `spacing(n)` / `spacingHalf(n)`. That is not a
coincidence to be maintained: `.Layout.Inset.T.4` and `.Pad.T.4` differ only in
the property name, and a test asserts the two length strings are equal.

`inset` is a real CSS shorthand, so `All` is one declaration. `left`/`right` and
`top`/`bottom` have none, so `X` and `Y` expand to two — which is how `§ 5.17`
prints `inset-x-0`.

### Overflow, overscroll, visibility, z-index, isolation

{layout-overflow-z/src/main.bp}

Two of these are places a transcription slips, so each has its own assertion:
`invisible` is the **utility** name and `hidden` is the **CSS value**, and `Z`
is the one numeric family in `Layout` that is **not a length** — `z-50` is the
bare integer `50`, never a `calc` and never a `rem`.

### Float, clear, replaced content

{layout-float-aspect/src/main.bp}

Three more traps, each pinned: the **utility** name is `float-start`, the CSS
**value** is `inline-start`; the hyphen in `object-left-bottom` belongs to the
utility name and the CSS value is two words separated by one space; and the
aspect ratios keep the spaces around the slash the way `§ 5.1` prints them.

### Multi-column, fragmentation, box-sizing

{layout-columns-box/src/main.bp}

A column **count** is a plain integer. A column **width** is the theme's
container ladder — `.Layout.Columns.Md` and `.Size.MaxW.Md` are the same width
by definition, so they are the same reference, and a project that overrides
`--container-md` moves both. No `Columns` leaf spells a `rem`.

`break-inside` carries a shorter leaf set than `break-after` / `break-before`:
`§ 5.5` has no `all`, no `page`, no `left` and no `right`.

The three are **flat sub-sections**, not `Break { After, Before, Inside }`. A
section head named like a top-level modifier variant silently shadows that
variant's payload, and `After`/`Before` are modifiers — see `AGENTS.md`
§ Maintainer rules.

**Not declared:** `columns-4` … `columns-12`, which resolve upstream through the
bare-integer rule rather than through a theme key; arbitrary `aspect-[4/3]` and
`z-[999]`, which belong to the escape-hatch front.

### Nothing in `Layout` resolves a length

`Layout` declares 776 leaves, and a test walks **every one of them** asserting
the emitted declaration carries no `rem`, carries a `:`, and carries no Tailwind
class fragment. `Inset` goes through `spacing(n)` / `spacingHalf(n)`; the named
column widths go through `var(--container-*)`; `Z` is a bare integer. Halving
`--spacing` or changing `--container-md` moves the `:root` block and not one
byte of any `Layout` rule.

`examples/emilia-layout/` is the worked example: a media card that clips its
overflow, isolates a stacking context and crops a 16:9 image; and a sticky
header over a one-axis scroll panel with a badge on a negative inset.

## Flex — `§ 6`

`Flex` is the flex CONTAINER and the flex ITEM. `display:flex` is not here — it
is a display value and lives on `Layout` (`.Layout.Flex`); this section is
everything a box that already declares it can say next.

### Direction and wrap

{flex-direction-wrap/src/main.bp}

### The shorthand, grow, shrink, basis and order

{flex-value-basis-order/src/main.bp}

The sub-section is `Value` and not `Flex`, because a section cannot carry a
sub-section of its own name.

`Basis` is the only family here that is a **length**, and it is front 35's
scale answering front 54's `spacing(n)` / `spacingHalf(n)` — `.Flex.Basis.4`
and `.Pad.All.4` carry the same length text because they call the same
function. Its fractions are front 35's `fraction(n, d)` strings, and a
test compares `.Flex.Basis.Frac.Third` to `.Size.W.Frac.Third` rather than to a
literal.

`Grow`, `Shrink` and `Order` are **bare numbers**: `order-1` is `order:1`, a
count and not a length, so nothing in them reaches the theme. `order-first`
and `order-last` are the sentinels `-9999` and `9999`, and `order-none` is `0`.

### Alignment — nine property groups, all under `Flex`

{flex-alignment/src/main.bp}

**Alignment applies to grid as much as to flex, and it lives under `Flex`
anyway.** `align-items` and `justify-content` were spelled that way before this
front, and renaming a token that compiles today is what the milestone forbids.
A grid container writes `.Flex.Justify.Center` and gets
`justify-content:center`, which is the correct CSS for a grid; only the token's
spelling reads as though it were flex-only.

**Upstream is not internally consistent and rakun-stylesheet copies it rather than
smoothing it.** `justify-content`, `align-items`, `align-self` and
`align-content` take `flex-start` / `flex-end`; `justify-items`,
`justify-self` and the whole `place-*` family take `start` / `end`. One test is
dedicated to the asymmetry, asserting both spellings come out of the right
tokens.

`AlignSelf` and the flat `PlaceContent` / `PlaceItems` / `PlaceSelf`, rather
than `Self` and a nested `Place { … }`: **`Self` is a language keyword**, so a
section cannot be named it. The family is flattened the way `Break` is, and no
emitted byte differs.

## Grid — `§ 6.8`–`§ 6.14`

`display:grid` is `Layout`'s (`.Layout.Grid`) and used to be all rakun-stylesheet had:
there was no template, no span, no start, no end, no flow and no implicit
track, so nothing could be put inside the box it declares.

{grid/src/main.bp}

A template is a **function of the leaf**, not a lookup: `gridRepeat(n)` builds
`repeat(N, minmax(0, 1fr))` — one space after each comma — and it is the only
place that text is spelled. The `minmax(0, 1fr)` inside it is `gridFr()`, the
same string the implicit `fr` tracks read, so the two cannot drift.

`Cols`, `Rows` and `Span` run **1 … 12**; `Start` and `End` run **1 … 13**,
because a twelve-column grid has thirteen lines.

**Nothing in `Grid` is a length.** A column count, a span and a line number are
integers, so no leaf reaches `spacing(n)` and none spells a `rem`.

**Not declared:** every arbitrary-value form (`grid-cols-[200px_1fr]`,
`col-start-[7]`), which belongs to the escape-hatch front.

## Gap — `§ 6.15`

{gap/src/main.bp}

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

### Nothing in `Flex`, `Grid` or `Gap` resolves a length

The three sections declare **356 leaves** (126 + 125 + 105), and a test walks
every one of them asserting the emitted declaration carries no `rem`, carries a
`:`, and carries no Tailwind class fragment. Only `Flex.Basis` and `Gap` are
lengths and both go through `spacing(n)` / `spacingHalf(n)`; a grow factor, an
order, a column count, a span and a line number are bare integers. The same
test carries a CONTROL, so the probe is known to discriminate rather than to
pass vacuously. The control has moved twice: it was `.Border.Rounded.Lg` until
front 40 rewrote the radius ladder to reference the theme, then `.Text.Size.Lg`
until front 38 did the same to the type scale. **No token in rakun-stylesheet resolves a
`rem` any more**, so the control is now a hand-built declaration beside the
same fact asserted from the other side.

`examples/emilia-grid/` is the worked example: a toolbar whose heading takes the
remaining space and which stacks under `sm`, and a twelve-column dashboard that
reflows one → six → twelve across `md` and `lg`.

## Table — `§ 14`

| Token | Emits |
| --- | --- |
| `.Table.Collapse` / `.Table.Separate` | `border-collapse:collapse` / `separate` |
| `.Table.Layout.Auto` / `.Fixed` | `table-layout:auto` / `fixed` |
| `.Table.Spacing.__N` (0, 1, 2, 4, 8) | `border-spacing:calc(var(--spacing) * N)` (`0` for 0) |
| `.Table.SpacingX.__N` / `.SpacingY.__N` | `border-spacing:<n> 0` / `border-spacing:0 <n>` |
| `.Table.Caption.Top` / `.Bottom` | `caption-side:top` / `bottom` |

The two axes are the two-value form of one property, so an X and a Y token in
one list do not add up — the last wins. Arbitrary values:
`rawTableSpacing("1px 2px")` (`Token.TableSpacingRaw`).
