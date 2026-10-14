# emilia — user docs

emilia is the CSS-in-bp library for the rakun-bpp stack. You
write styles by **listing typed tokens**; emilia turns each token into a
CSS declaration, hashes the resulting body into a stable class name,
and collects every class on a per-render `<style>` registry.

## Install

`repository/emilia/botopink.json` is a **workspace** (decision 75 of
1.0.10-beta): `from "rakun-stylesheet"` resolves to the member `modules/rakun-stylesheet/` —
whose `files` (`root.bp`, `tokens.bp`, `emilia.bp`) is exactly what a
consumer sees — and never to the umbrella, which ships nothing.
`dependencies` is the object form only (decision 76); the string array is a
located error in every tool:

```jsonc
// botopink.json
{
  "dependencies": {
    "rakun-bpp": { "git": "https://github.com/botopink/rakun.git", "branch": "feat" },
    "rakun-stylesheet": { "git": "https://github.com/botopink/rakun.git", "branch": "feat" }
  }
}
```

A sibling member of emilia's own workspace writes `{ "emilia": { "workspace":
true } }` instead — that is what [`examples/emilia-card/`](../examples/emilia-card/)
does — and a project elsewhere in the ecosystem `{ "path": "…/modules/rakun-stylesheet" }`.

Bare `import { emilia, flush, Token } from "rakun-stylesheet"` resolves at v0;
the `import emilia from "rakun-stylesheet"` package-handle form is a recorded
follow-up (binds the handle but doesn't currently lower the bare
`emilia(…)` call).

## Quickstart

<!-- example: quickstart -->

## Preflight — the reset, opt-in

Tailwind's utilities assume a reset (`§ 4`): `border` is `1px` visible only
because everything already has `border-width:0;border-style:solid`, and
`before:`/`after:` render only because `content:""` is set. emilia ships the
reset and never applies it on its own:

<!-- example: preflight -->

Eleven rules in the `base` layer: box-sizing and zero-width solid borders on
everything, `html`'s line-height, margins off `body`, headings and lists,
inherited link colour and decoration, block images, inherited fonts in form
controls, and `content:""` on `::before`/`::after`. Parity with `§ 4`, not a
byte copy of upstream's `preflight.css`.

## Container queries — `§ 3.3`

A parent becomes a container; a descendant asks about the container's width,
not the viewport's:

<!-- example: container-queries -->

The thirteen builders `containerAt3xs` … `containerAt7xl` read `--container-*`
from the theme (16rem … 80rem by default), so overriding `--container-md` moves
every `md` query. `containerNamed(ContainerSize.Sm, "main", inner)` is `@sm/main:`
— `@container main (width >= 24rem)`. A size the theme does not define panics.
Do not import `ContainerSize` into a module that writes `Token.Sm(…)` (see the
maintainer notes).

## Putting the class on an element

<!-- example: class-on-element -->

The class is a pure function of the token list, in order, and of the theme; a
token list whose CSS is not ASCII is refused rather than hashed differently on
the two targets.

## Your own utilities and variants

A bundle is a function; `@apply` is `append`; a custom variant is a function
over the inner list; a class whose NAME is part of your API is `named`:

<!-- example: own-utilities -->

`named` refuses a name starting with `e_`, a name outside `[A-Za-z0-9-_]`, and a
second registration of the same name with different tokens. A utility on the
same element beats it, because `components` is layered before `utilities`.

## Arbitrary values — the escape hatches

When no token names the value, build one — every builder validates its payload:

<!-- example: arbitrary-values -->

A payload that could close the rule or the `<style>` element (`{ } < > ; @ \`
in a value, anything but `[A-Za-z0-9-_]` in a name, a selector without exactly
one `&`, a length without a unit) is REFUSED, never escaped: the comptime
validators (`cssValue`, `cssIdent`, `cssSelector`, `cssQuery`, `cssLength`) fail
the build, and the builders `@panic` at run time. `ArbMin`/`ArbMax` are
`@media (width >= …)` / `(width < …)`; `arbAt` adds the `@`.

## The `Token` enum

Every utility is a typed enum variant. Unknown variants are type errors
at the call site, not runtime fall-throughs. The full v0 surface (with
the values each variant emits) lives in
[`modules/rakun-stylesheet/src/tokens.bp`](../modules/rakun-stylesheet/src/tokens.bp); the highlights:

### Text, Font and List — `§ 9`

Thirty-two property groups. The listing below is by group; every leaf is in
[`tokens.bp`](../modules/rakun-stylesheet/src/tokens.bp).

**A size is TWO declarations.** Upstream's `text-lg` sets a font-size AND the
line-height paired with it, and both are theme references:

<!-- example: text-size -->

Thirteen sizes: `Xs Sm Base Lg Xl X2xl X3xl X4xl X5xl X6xl X7xl X8xl X9xl`.
The values are front 54's `defaultTheme()`, so a project that overrides
`--text-lg` moves every `text-lg` rule and no class name changes.

<!-- example: font-family-weight -->

Nine weights: `Thin Extralight Light Normal Medium Semibold Bold Extrabold
Black`, `100` through `900`. The weights stay LITERAL — that is the form the
reference prints — while the families are references, and the three stacks live
in `typographyEntries()`, copied from upstream v4's `theme.css` (the reference
prints none).

<!-- example: font-smoothing-style -->

Nine stretch values (`UltraCondensed ExtraCondensed Condensed SemiCondensed
Normal SemiExpanded Expanded ExtraExpanded UltraExpanded`) and nine numeric
variants (`Normal Ordinal SlashedZero Lining Oldstyle Proportional Tabular
DiagonalFractions StackedFractions`).

**Tracking and leading** are references too; `leading-none` is the one leaf the
reference prints as a literal:

<!-- example: text-tracking-leading -->

**The decoration family.** The line is the LONGHAND, which is what lets it
compose with a style instead of overwriting it:

<!-- example: text-decoration -->

`Decoration.Color` is the SAME 26 x 11 grid `Color` and `Bg.Color` carry, through
the same `paletteVar`, so a decoration colour and a text colour cannot drift.

**Alignment, transform, overflow and wrap:**

<!-- example: text-align-transform -->

`Clamp` runs `1` to `6` plus `None`, and `None` is the four-declaration RESET
rather than the absence of a token.

**Whitespace, breaking, hyphens, indent, align, tab, content:**

<!-- example: text-whitespace-break -->

- **`Break` and `OverflowWrap` are two sections, not one.** Upstream's `break-*`
  and `wrap-*` overlap in EFFECT and not in PROPERTY — `break-words` is an
  `overflow-wrap` although it is spelled `break-` — and merging them would lose
  `wrap-anywhere`, which has no `break-*` spelling at all.
- **`Text.Indent` never resolves a length.** It answers front 54's
  `spacing(n)`, the same function `.Pad.All.8` answers, so the two agree by
  construction.
- **`.Text.Bold` and `.Text.Italic` are emilia's own leaves**, not
  transcriptions of a Tailwind utility; `font-weight:bold` is what they emitted
  before `§ 9` landed and what they emit now.

### List — `§ 9.12`–`§ 9.14`

<!-- example: list-style -->

Top-level, because `list-style-*` applies to the list and not to its text.

### Color — the palette

Twenty-six families of eleven shades, and **the token emits a reference, not a
value**:

<!-- example: color-palette -->

The families are the seventeen chromatic (`Red Orange Amber Yellow Lime Green
Emerald Teal Cyan Sky Blue Indigo Violet Purple Fuchsia Pink Rose`) and the
nine neutral (`Slate Gray Zinc Neutral Stone Mauve Olive Mist Taupe`); every
one of them answers all eleven shades `50 100 200 300 400 500 600 700 800 900
950`.

`var(--color-red-500)` is byte-equal with what upstream's own `.text-red-500`
rule emits, and it means a project that overrides `--color-red-500` moves every
rule that names it. The numbers live in the theme, not in the rule — see
[The colour palette](#the-colour-palette).

**All 286 cells are reachable.** Six of them — `.Color.Red.{100,500,700}` and
`.Color.Gray.{100,500,700}` — used to compile in no spelling, because the
compiler resolved a leading-dot section path by scanning every registered enum
(the synthesised section enums included) and returning the first whose tree
carried the path, without consulting the expected type: `Token` carries
`Color.Red.500` and so does `Token.Border.Color`, whose Red and Gray also run
100/500/700, so the winner was decided by hash order. It red at the call site
rather than emitting the wrong CSS. The resolver now prefers the enum the
expected type names, accepts the fully qualified `Token.Color.Red.500`, and
refuses an ambiguous path instead of guessing.

`Token.Border.Color` has since been widened to this same full grid (front 40),
so the two sections now carry the same 286 cells and the same eleven shades.
That is **not** what fixed the collision, and it would not have: the resolver
fix is what makes both reachable, and the standing rule is that a collision
like this is never resolved by adding or renaming a type to flip a hash.

### Bg.Color — the same palette on `background-color`

<!-- example: bg-color -->

Same 26 families, same eleven shades, one property along — and **all 286 cells
resolve**, because `Bg` is a head segment no other enum carries. It is the way
to reach the six shades `.Color.Red` / `.Color.Gray` cannot.

The property is `background-color` and not `background`. Upstream's `bg-*`
colour utilities set the longhand; the shorthand the v0 stub emitted resets
every other background property of the element as a side effect.

The four **legacy** `Bg` leaves keep what they emitted before the palette
landed, so nothing that compiled changed meaning. Front 39 did **not** fold
them in: they still emit the `background` shorthand, and changing what a
compiling path means is not something a front does to another front's surface.
Reach for `.Bg.Color.*` in new code.

<!-- example: bg-legacy -->

### Bg — the rest of the background, `§ 10.1`–`§ 10.8`

Seven keyword sub-sections sit beside `Bg.Color`. Each is one declaration, and
none of them resolves a length or reads the theme.

<!-- example: bg-keywords -->

Three names are worth reading twice:

- **`Pos`, not `Position`.** `.Bg.Pos.Center` sets `background-position` and
  `.Layout.Position.Fixed` sets `position`; Tailwind spells both with the same
  English word and they are unrelated properties. The short head keeps the path
  four segments and keeps the two apart at a glance.
- **`Repeat.None`, not `Repeat.NoRepeat`.** The CSS value keeps its `no-`
  prefix; the token does not repeat the word its own section already says.
- **`Clip.Text` is the one clip value that is not a `*-box`.** The suffix is
  written per arm rather than derived from the leaf name, because a derived
  rule would emit `text-box` — a different value that also exists.

`.Bg.Size.*` and the top-level `Size` section are two different things:
`background-size` and the element's own `width`/`height` ladder. The same
shape as `.Bg.Color` beside the top-level `Color`.

Nothing else in `§ 10.4` is a token: `bg-[url(…)]`, `bg-size-[…]` and
`bg-position-[…]` are arbitrary values and belong to the escape-hatch front.

### Gradient — `§ 10.4`

Gradients are their own top-level section, not a sub-section of `Bg`. The stop
colours are not `background-image` at all — they are custom properties the
gradient reads — so nesting them under `Bg.Image` would put three properties
under one name; and a stop is a four-segment path already.

**`To` is the direction. `Stop` is the terminal colour.** Tailwind spells both
with the word `to` (`bg-gradient-to-r` and `to-pink-500`) while they set
unrelated things; emilia does not.

<!-- example: gradient-direction -->

A corner is **two keywords** — `to top right`, never `to top-right` — and there
is exactly one space after the comma. The eight phrases are spelled in one
place in `emilia.bp`, so adding a direction is one arm.

#### The stops

`From`, `Via` and `Stop` each carry the **whole of front 33's grid** — the 26
families over eleven shades, plus `White`, `Black`, `Transparent`, `Current`
and `Inherit`. The colour half is `paletteVar(family, shade)`, the same
function `.Bg.Color.*` calls, so a stop and a background reference ONE custom
property by construction:

<!-- example: gradient-stops -->

A full gradient is a direction and two or three stops in one list:

<!-- example: gradient-full -->

**Token order is load-bearing here**, and deliberately so. `Via` writes a
three-stop list and `From` a two-stop one; whichever is listed LAST wins, which
is how a `From` + `Via` + `Stop` triple ends up with the three-colour list.
`Stop` writes no list at all — if it did, it would overwrite `Via`'s.

#### What the stop shape does and does not take from upstream

The three custom-property names are upstream's, checked against it:
`--tw-gradient-from`, `--tw-gradient-via`, `--tw-gradient-to`, read by
`var(--tw-gradient-stops)` in the direction.

The **composition** is simpler than upstream's on purpose. Tailwind v4 threads
four position variables through the list and gives `via-*` its own
`--tw-gradient-via-stops`, and both rest on `@property` registration for their
defaults. emilia registers no `@property` for them, and colour-stop positions
(`from-10%`) are not tokens here, so copying that shape would emit a list that
is invalid at computed-value time in every browser.

What is kept is the part that makes the simplification correct: upstream
registers `#0000` as each stop's default, and emilia writes that as a
`var(…, transparent)` **fallback**. So `.Gradient.From.Indigo.500` on its own
still paints indigo → transparent rather than resolving to nothing.

Radial and conic gradients (`bg-radial`, `bg-conic`), the interpolation
suffixes (`bg-linear-to-r/oklch`) and colour-stop positions (`from-10%`) are
**not** tokens: a radial gradient is a different function with a position
argument, and specifying it from memory would be guessing.

### `Color.Hex("#abc")` is declared and unconstructible

The `Hex(value: string)` leaf is kept — it is the proof that a string payload
splices into the emitted CSS, and `colorTokenToCss` still matches it — but
**no caller can build one**. Measured against the compiler, on this enum:

```text
Token.Color.Hex("#abc")
  error: 'Hex' is not declared in any behavior implemented for 'Token'
val h: Token = .Color.Hex("#abc");
  error: unbound variable 'Color'
```

A payload leaf nested inside a section has no constructible spelling; the
variant type-checks in a `case` pattern, so the surface looks complete and is
not. The shape that builds is a **top-level** variant with builtin-typed
fields — which is what `Alpha(percent: i32, inner: Token[])` is, and what
front 41's `EffectShadowRaw(value: string)`, `EffectTextShadowRaw(value:
string)` and `MaskImageRaw(value: string)` are.

> **The second message has changed since it was recorded**, re-measured by
> front 41 against compiler `2e6bb4ac` and against this enum. The qualified
> form still reports `'Hex' is not declared in any behavior implemented for
> 'Token'`; the dot form now reports **`'Hex' is not declared in any behavior
> implemented for 'Ns'`** — the leading-dot resolver walked `.Color` into
> front 54's `Ns` enum, which also has a `Color` member, instead of into the
> annotated type `Token`. The gap is unchanged and the diagnostic is worse: it
> names a type the author never mentioned. (In an enum with no such sibling in
> scope the same two forms report `unknown field '<Section>' on type '<Enum>'`
> and `unbound variable ''` — an empty name — which is the spelling the
> milestone's `language-gaps.md` rows 51 and 52 still carry.)

Nothing in the palette depends on the enum, which is why that gap costs this
front nothing: `paletteVar(family, shade)` and `alphaWrap(percent, css)` take
plain strings and are `pub`, and the property name (`color:`,
`background-color:`) lives in the dispatcher rather than in the value. A
colour emilia's enum does not carry formats through the same functions.

### Alpha — opacity, upstream's `/N` suffix

<!-- example: alpha -->

`bg-red-500/50` is a **wrapper**, not a leaf. Opacity cannot hang under the
family — the shade is already the leaf, and a second numeric level would
multiply the grid to 26 × 11 × 21 — and a payload leaf nested inside a section
has no constructible spelling, so `Alpha` is a top-level variant with a
builtin-typed field, the shape `Hover(inner: Token[])` already has.

It rewrites the VALUE of every declaration its inner tokens produce, rule by
rule, so the selector and at-rule of a modifier inside it survive and it
composes in either order:

<!-- example: alpha-modifier-order -->

A **non-colour** token is rewritten too, and the result is meaningless CSS
(`font-weight:color-mix(in oklab, bold 50%, transparent)`). That is
deliberate: dropping the declaration silently would hide the mistake, and one
a browser discards is visible in devtools the moment it is looked for.

### Pad and Margin

**Nine directions each** — `All`, `X`, `Y`, `T`, `R`, `B`, `L`, and the logical
pair `S`/`E` that follows the writing direction where left and right do not.

<!-- example: pad -->

CSS has **no `padding-x` property**, so an axis token is two declarations, not
one. Until this front emilia emitted `padding-x:`, `padding-y:` and `margin-y:`
— property names no browser knows, silently discarded — and the `Margin.X`
ladder emitted `m-0.25`, `m-1` and `margin-auto`, which are Tailwind class
fragments rather than declarations. Those eight spellings are gone, and a test
asserts each of them is.

#### The scale

Every direction answers the same 35 leaves: the thirty multipliers
`0 1 2 3 4 5 6 7 8 9 10 11 12 14 16 20 24 28 32 36 40 44 48 52 56 60 64 72 80 96`,
the pixel step `Px`, and `Half { 0, 1, 2, 3 }`.

<!-- example: spacing-scale -->

`0.5` cannot be an enum leaf — a numeric leaf is a run of digits — so `Half.1`
reads "one and a half" and `Half { 0, 1, 2, 3 }` covers `0.5`, `1.5`, `2.5` and
`3.5`. **A spacing value is never resolved here**: every leaf answers
`spacing(n)` or `spacingHalf(n)`, so `--spacing` stays the one place the length
is decided (§ Spacing — `spacing(n)`).

#### `Auto` and `Neg`, on margin

`Auto` is a value on the ladder, so it is on **every** margin direction and gets
the same expansion every multiplier gets. `Neg` is upstream's `-mt-4`, the one
family of utilities with no alternative spelling:

<!-- example: margin-auto-neg -->

`Neg` carries no `0` and no `Auto` — a negative zero and a negative auto are not
utilities — and its `Half` is `{ 0, 1, 2, 3 }`, answered by the theme's
`spacingNegHalf`: `.Margin.T.Neg.Half.0` is `-mt-0.5`,
`margin-top:calc(var(--spacing) * -0.5)`.

### Size

Thirteen sub-sections: `W`, `H`, `Both`, `MinW`, `MaxW`, `MinH`, `MaxH`, and the
six logical forms `Inline`, `Block`, `MinInline`, `MaxInline`, `MinBlock`,
`MaxBlock`. Four kinds of leaf.

<!-- example: size-kinds -->

`1/2` is neither an identifier nor a run of digits, so a fraction cannot be a
leaf; `Frac` carries the eleven upstream fractions by name — `Half`, `Third`,
`TwoThirds`, `Quarter`, `ThreeQuarters`, `Fifth`, `TwoFifths`, `ThreeFifths`,
`FourFifths`, `Sixth`, `FiveSixths`. Each is upstream v4's `calc(N / D * 100%)`,
spelled once by `fraction(n, d)`, and every `Frac` in the library — sizes,
insets, flex bases, translates — reads it.

**The viewport unit differs by axis** and the tests say so:

<!-- example: size-viewport -->

`Both` is upstream's `size-*` — two declarations from one leaf:

<!-- example: size-both -->

#### The named widths are the theme's, not emilia's

`max-w-md` is `max-width:var(--container-md)` upstream and here. The `rem`
behind each name is written once, in the theme, so a project that redefines
`--container-md` moves every `max-w-md` in the build — which a literal ladder in
the dispatcher would have made impossible.

<!-- example: size-named-widths -->

`MaxW` carries all thirteen container names, `X3xs` and `X2xs` through `X7xl`,
and `MaxW.Screen` the five breakpoints. No `Size` leaf emits a `rem` of its own;
a test walks all 566 of them and asserts it.

### Space — spacing between children

`space-x-*` and `space-y-*` are **not declarations on the element**. They set a
margin on its children, so a `Space` token produces a rule with its own
selector:

<!-- example: space-between-children -->

Two rules of one class, because they do not describe the same elements. This is
upstream v4's form (verified against `utilities.ts`): the child selector is
wrapped in `:where()` so it adds no specificity, and the gap is split between
the logical START and END margins through the reverse flag — `0` by default, so
the gap sits at the end, and `.Space.XReverse` / `.Space.YReverse` (the flag at
`1`) move it to the start. The scale is the one `Pad` and `Margin` use, `Neg`
included; a zero step is a bare `0` on both sides.

The selector is a nesting template carrying exactly one `&`, so a modifier
wraps it rather than replacing it:

<!-- example: space-modifier -->

**Recorded, not hidden:** `space-x-*` is absent from the local Tailwind
reference entirely, so the child selector and the properties were read from
upstream's `utilities.ts` (2026-09-26) rather than transcribed, and the
`--tw-space-*-reverse` names are
upstream-internal and unverified. Both are pinned by a test, so changing them
is a visible change.

### Layout — `§ 5`

`Layout` is two things at once. The **eleven display values are the section's
own leaves**, so `.Layout.Flex` is a display value and not a flex container:

<!-- example: layout-display -->

`hidden` is the one row whose Tailwind name is not its CSS value: `.Layout.Hidden`
is `display:none`. The flex and grid CONTAINER properties — direction, wrap,
alignment, `gap` — are `Token.Flex`'s, not `Layout`'s.

Everything else in `§ 5` is a **sub-section** beside those leaves.

#### Position and inset

<!-- example: layout-position-inset -->

`Inset` carries the **nine directions** `Pad` and `Margin` carry — `All`, `X`,
`Y`, `T`, `R`, `B`, `L` and the logical pair `S`/`E` — over the **same scale**,
answering the **same** `spacing(n)` / `spacingHalf(n)`. That is not a
coincidence to be maintained: `.Layout.Inset.T.4` and `.Pad.T.4` differ only in
the property name, and a test asserts the two length strings are equal.

`inset` is a real CSS shorthand, so `All` is one declaration. `left`/`right` and
`top`/`bottom` have none, so `X` and `Y` expand to two — which is how `§ 5.17`
prints `inset-x-0`.

#### Overflow, overscroll, visibility, z-index, isolation

<!-- example: layout-overflow-z -->

Two of these are places a transcription slips, so each has its own assertion:
`invisible` is the **utility** name and `hidden` is the **CSS value**, and `Z`
is the one numeric family in `Layout` that is **not a length** — `z-50` is the
bare integer `50`, never a `calc` and never a `rem`.

#### Float, clear, replaced content

<!-- example: layout-float-aspect -->

Three more traps, each pinned: the **utility** name is `float-start`, the CSS
**value** is `inline-start`; the hyphen in `object-left-bottom` belongs to the
utility name and the CSS value is two words separated by one space; and the
aspect ratios keep the spaces around the slash the way `§ 5.1` prints them.

#### Multi-column, fragmentation, box-sizing

<!-- example: layout-columns-box -->

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

#### Nothing in `Layout` resolves a length

`Layout` declares 776 leaves, and a test walks **every one of them** asserting
the emitted declaration carries no `rem`, carries a `:`, and carries no Tailwind
class fragment. `Inset` goes through `spacing(n)` / `spacingHalf(n)`; the named
column widths go through `var(--container-*)`; `Z` is a bare integer. Halving
`--spacing` or changing `--container-md` moves the `:root` block and not one
byte of any `Layout` rule.

`examples/emilia-layout/` is the worked example: a media card that clips its
overflow, isolates a stacking context and crops a 16:9 image; and a sticky
header over a one-axis scroll panel with a badge on a negative inset.

### Flex — `§ 6`

`Flex` is the flex CONTAINER and the flex ITEM. `display:flex` is not here — it
is a display value and lives on `Layout` (`.Layout.Flex`); this section is
everything a box that already declares it can say next.

#### Direction and wrap

<!-- example: flex-direction-wrap -->

#### The shorthand, grow, shrink, basis and order

<!-- example: flex-value-basis-order -->

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

#### Alignment — nine property groups, all under `Flex`

<!-- example: flex-alignment -->

**Alignment applies to grid as much as to flex, and it lives under `Flex`
anyway.** `align-items` and `justify-content` were spelled that way before this
front, and renaming a token that compiles today is what the milestone forbids.
A grid container writes `.Flex.Justify.Center` and gets
`justify-content:center`, which is the correct CSS for a grid; only the token's
spelling reads as though it were flex-only.

**Upstream is not internally consistent and emilia copies it rather than
smoothing it.** `justify-content`, `align-items`, `align-self` and
`align-content` take `flex-start` / `flex-end`; `justify-items`,
`justify-self` and the whole `place-*` family take `start` / `end`. One test is
dedicated to the asymmetry, asserting both spellings come out of the right
tokens.

`AlignSelf` and the flat `PlaceContent` / `PlaceItems` / `PlaceSelf`, rather
than `Self` and a nested `Place { … }`: **`Self` is a language keyword**, so a
section cannot be named it. The family is flattened the way `Break` is, and no
emitted byte differs.

### Grid — `§ 6.8`–`§ 6.14`

`display:grid` is `Layout`'s (`.Layout.Grid`) and used to be all emilia had:
there was no template, no span, no start, no end, no flow and no implicit
track, so nothing could be put inside the box it declares.

<!-- example: grid -->

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

### Gap — `§ 6.15`

<!-- example: gap -->

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

#### Nothing in `Flex`, `Grid` or `Gap` resolves a length

The three sections declare **356 leaves** (126 + 125 + 105), and a test walks
every one of them asserting the emitted declaration carries no `rem`, carries a
`:`, and carries no Tailwind class fragment. Only `Flex.Basis` and `Gap` are
lengths and both go through `spacing(n)` / `spacingHalf(n)`; a grow factor, an
order, a column count, a span and a line number are bare integers. The same
test carries a CONTROL, so the probe is known to discriminate rather than to
pass vacuously. The control has moved twice: it was `.Border.Rounded.Lg` until
front 40 rewrote the radius ladder to reference the theme, then `.Text.Size.Lg`
until front 38 did the same to the type scale. **No token in emilia resolves a
`rem` any more**, so the control is now a hand-built declaration beside the
same fact asserted from the other side.

`examples/emilia-grid/` is the worked example: a toolbar whose heading takes the
remaining space and which stacks under `sm`, and a twelve-column dashboard that
reflows one → six → twelve across `md` and `lg`.

### Border — `§ 11.1`–`§ 11.4`

<!-- example: border-width-style-color -->

An **axis** is two declarations and a **side** is one, because CSS has no
`border-x-width`. The logical pair `S`/`E` is
`border-inline-start-width`/`-end-width`, which follows the writing direction
where `L`/`R` do not — the same distinction `Pad.S`/`Pad.E` draws.

`Border.Color` carries the whole of [the palette](#color--the-palette): 26
families × 11 shades, plus `White`/`Black`/`Transparent`/`Current`/`Inherit`.
Every cell goes through the same `paletteVar(family, shade)` that `Color`,
`Bg.Color`, `Outline.Color`, `Ring.Color` and `Divide.Color` use, so
`.Border.Color.Emerald.600` and `.Color.Emerald.600` reference **one** custom
property and cannot drift apart.

> **This changed what a compiling path means.** Before front 40 the dispatcher
> DISCARDED the shade — every cell emitted `border-color:red` or
> `border-color:gray`. Three shades of one family were therefore ONE class,
> since the class name is a hash of the body. If you pinned that text, it moved.

`.Border.Color.Hex(value)` is declared and, like every payload leaf nested in a
section, **cannot be constructed** — see
[`Color.Hex` is declared and unconstructible](#colorhexabc-is-declared-and-unconstructible).

#### Border radius — `§ 11.1`, `§ 21.5`

<!-- example: border-radius -->

Ten leaves — `None`, `Xs`, `Sm`, `Md`, `Lg`, `Xl`, `X2xl`, `X3xl`, `X4xl`,
`Full` — on the shorthand **and on each of fourteen directional sub-sections**:
the four sides `T`/`R`/`B`/`L`, the four physical corners `Tl`/`Tr`/`Br`/`Bl`,
and the six logical ones `S`/`E`/`Ss`/`Se`/`Es`/`Ee`. A **side** form emits two
corner properties and a **corner** form emits one, so `.Border.Rounded.Tl.Full`
is as much a path as `.Border.Rounded.Tl.Lg` is.

> **This changed too.** `Sm`, `Md` and `Lg` used to resolve a literal `rem`;
> they reference `var(--radius-*)` now, so overriding `--radius-lg` moves every
> rounded corner. `Full` and `None` do **not** change — upstream prints those two
> literally, and neither is a theme entry.

`examples/emilia-borders/` is the worked example: one width per side, the two
axes, the six styles, the palette with its shade, and a table-like card with a
rounded top, a square bottom and a dashed internal rule.

### Outline — `§ 11.5`–`§ 11.8`

<!-- example: outline -->

An outline is painted **outside** the border box and **takes no space**, which
is why a focus ring is an outline and not a border: focusing a control moves
nothing beside it.

<!-- example: outline-focus-visible -->

> **`.Outline.Style.None` is the trap.** It is **not** `outline-style:none`.
> Upstream prints it as a *transparent* outline plus an offset, so a
> high-contrast mode still renders a ring where the design removed one. The
> token sits under `Style` because that is where upstream puts it; only the
> emission is special.

A negative offset is a leaf on a `Neg` sub-section and not a sign on a number,
because a numeric enum leaf is a run of digits.

### Ring — the box-shadow half of a focus ring

**Every shadow and ring token writes ONE channel and the same reader**, upstream
v4's five-channel `box-shadow`:
`var(--tw-inset-shadow, 0 0 transparent), var(--tw-inset-ring-shadow, 0 0 transparent), var(--tw-ring-offset-shadow, 0 0 transparent), var(--tw-ring-shadow, 0 0 transparent), var(--tw-shadow, 0 0 transparent)`.
So `[.Ring.W.2, .Effect.Shadow.Md]` draws both — and a lone ring draws at all:
each channel falls back to a null shadow, where an unset channel would otherwise
invalidate the whole declaration.

<!-- example: ring -->

A ring **composes with a shadow rather than overwriting it**: the `box-shadow`
declaration *lists* `var(--tw-shadow)` instead of writing a shadow of its own,
so a `Ring` token and an `Effect.Shadow` token in the same list both reach the
output. Token order is class identity, so swapping the two is a different class
— which is the sharpest case [contract 4](#stable-hashes--sites-collapse) has.

`.Ring.W.1` is upstream's bare `ring`. **The v4 default is 1px**, where v3's was
3px.

> **Verified and unverified.** The custom property names, the inset flag and the
> v4 default width were checked against upstream. The composed `box-shadow`
> list and the whole `ring-offset-*` family were **not** confirmed — v4's
> documentation no longer carries `ring-offset-*` at all. Both are declared
> because the surface asks for them, and both are recorded here rather than
> presented as transcribed.

### Divide — borders between children

<!-- example: divide -->

`divide-*` declares on the element's **children**, not on the element — a
border on every child but the last — so the class body itself is **empty**:

<!-- example: divide-class -->

A width, a colour and a style all target the **same** selector, so they merge
into one child rule rather than three.

That selector is the same one [`Space`](#space--spacing-between-children) uses,
and it is spelled in exactly one place in the library — `siblingSelector()`.
`divide-*` and `space-y-*` separate the same children, and a test compares the
two families' output **byte for byte** so that the two can never be written
differently.

`examples/emilia-outline-ring/` is the worked example for all three sections.

#### Nothing in `Border`, `Outline`, `Ring` or `Divide` resolves a colour or a radius

The four sections declare **1704 leaves** (492 + 310 + 593 + 309), and a test
walks every one of them asserting the declaration carries no `rem`, no hex and
no colour function; carries a `:`; and carries no Tailwind class fragment. Each
walk has a control that must fail, and one further walk asserts that all 1440
colour cells carry a `var(--color-` reference and that a section's 288 are 288
**distinct** strings — because a literal probe alone does not catch a dispatcher
that discards its shade, which is exactly the defect this section used to have.

### Effect, Blend and Mask — `§ 12`

Three sections, one hundred and two leaves, and the only place emilia ever
shipped CSS a browser throws away.

#### The defect, stated plainly

`.Effect.Shadow.Md` used to emit **`box-shadow:md`**. That is the Tailwind
class suffix in the position a CSS value belongs; a browser discards the whole
declaration, so a card that asked for a shadow rendered flat. All four of
`Sm`/`Md`/`Lg`/`Xl` did it, and the only assertion that touched the family
pinned the wrong string. The four leaf **names** did not move, so nothing
that compiled before stops compiling; what they emit is the fix.

<!-- example: effect-shadow-fix -->

#### Shadows

<!-- example: effect-shadow -->

A leaf may not start with a digit, so upstream's `2xs` and `2xl` are spelled
`X2xs` and `X2xl`. The **emitted variable keeps upstream's name** —
`--shadow-2xs`, not `--shadow-x2xs`.

An **inset shadow is not a longhand**. CSS has no `inset-box-shadow`; the
property is `box-shadow` and `inset` leads the value. `.Effect.InsetShadow.Sm`
and `.Effect.Shadow.Sm` therefore set the same property, and the later token in
a list wins.

`Shadow.Inner` is the **one literal in the whole section**. Upstream has no
`--shadow-inner` variable and `§ 12.1` prints the value inline, so writing it
as a theme lookup would invent a variable the reference does not have. Every
other step of every scale is a `var(…)` reference — a test walks all 102 leaves
asserting exactly one of them resolves a shadow value, and asserts from the
other side that the one is `Shadow.Inner`.

> **The stock theme carries `--shadow-*` and neither of the other two.**
> `--inset-shadow-*` is a real `Ns` namespace and a project adds its three
> entries through `extendTheme`. `--text-shadow-*` is **not** an `Ns`
> namespace — front 54's nineteen do not include it — so those entries are
> accepted under the `--text-` prefix instead, which is where `namespace(th,
> Ns.Text)` finds them and where `clearNamespace(th, Ns.Text)` would drop
> them. A real `Ns.TextShadow` is front 54's to add.

#### Opacity

Twenty-one steps, each upstream v4's **percentage** — `opacity:60%`, where the
reference prints the v3 fraction `opacity:0.6`.

<!-- example: effect-opacity -->

A numeric leaf is three spellings for one thing: bare digits in the
declaration, `.Effect.Opacity.60` in expression position, `__60` in a `case`
pattern.

`§ 12.3` prints fifteen steps. Six more — `15`, `35`, `45`, `55`, `65`, `85` —
are declared and confirmed against upstream's compiled `opacity-<n>`, which the
reference carries no row for.

#### Blend modes

`mix-blend-mode` blends an element with what is **behind** it;
`background-blend-mode` blends an element's own background layers with **each
other**. `§ 12.5` says in one sentence that the two take the same seventeen
values, which is why they are two sub-sections of one section.

<!-- example: blend -->

The two value tables are written twice, because two enum types cannot share a
`case`. A test strips the property name off each side and asserts the seventeen
values are **equal, in order**, so a typo in one and not the other reddens here
rather than in a browser.

#### Masks

Nine properties, nine sub-sections, every value a CSS keyword. Nothing in
`Mask` reads the theme.

<!-- example: mask -->

**The class suffix is not the CSS value.** `mask-clip-border` sets
`border-box`; a transcription that copied the suffix across would give
`mask-clip:border`, which is the same shape of defect as `box-shadow:md`.

`mask-type` is the only member of the family that declares on the **mask**
element rather than on the masked one, which is why it and `mask-mode` are two
properties over the same two words.

`§ 12.6` prints twenty rows. Nine more leaves — `Position.{Top,Bottom,Left,
Right}`, `Repeat.{RepeatX,RepeatY,Round,Space}` and `Size.Auto` — complete the
three keyword ladders; each is confirmed against upstream v4's compiled output.

#### Arbitrary values — `rawShadow`, `rawTextShadow`, `rawMaskImage`

Upstream's `shadow-[…]`, `text-shadow-[…]` and `mask-image-[…]` are
**top-level variants with a payload**, not leaves inside their section: a
payload leaf nested inside an enum section cannot be constructed by any
spelling (see *`Color.Hex("#abc")` is declared and unconstructible*). The name
keeps the path it would have had, flattened.

<!-- example: mask-raw -->

The three wrappers exist because a **leading-dot path followed by a payload
call does not carry the typed-array context** — `[.EffectShadowRaw("…")]` does
not parse. `Token.EffectShadowRaw(value: "…")` in full does, and so does a call
to one of the wrappers; they produce the same token and the same class.

The reference prints no arbitrary-value form; each was measured against
upstream v4. `rawShadow` is upstream's shape — the value goes into
`--tw-shadow` and the rule writes the five-channel `box-shadow` reader, so it
composes with a ring as `Effect.Shadow` does. `rawTextShadow` and
`rawMaskImage` set upstream's property (`text-shadow`, `mask-image`) and stay
**provisional** in one respect, marked at their arm: upstream rewrites a colour
inside a text shadow through `--tw-text-shadow-color`, which a raw string does
not.

#### Nothing in `Effect`, `Blend` or `Mask` resolves a shadow

The three sections declare **102 leaves** (39 + 34 + 29), and a test walks every
one of them asserting the declaration carries a `:`; carries no bare Tailwind
scale step as its value; and carries no Tailwind class fragment. Each probe has
a control that must fail **and** a control proving it does not fire on correct
output — `var(--shadow-sm)` legitimately contains `shadow-sm`, so the scale
probe anchors on the colon and a naive `indexOf("shadow-sm")` would have fired
on the fix. One further walk asserts the fifteen scale references are fifteen
**distinct** strings.

`examples/emilia-effects/` is the worked example: the catalogue, then a photo
card that sits on the small shadow with its image multiplied into the page and
lifts to the extra-large shadow at full opacity on hover.

#### Not declared

`shadow-<color>/<opacity>` — upstream's `shadow-red-500/50`. `§ 12.1` gives the
class and the prose "Cor da sombra com opacidade" and **no property/value
pair**. The mechanism is no longer missing: front 56's `Rule.declarations` can
express the two-step protocol, where the colour utility writes a custom
property and the shadow utility reads it back. The **value** still is, so there
is nothing byte-equal to emit, and it reopens the moment the reference carries
a row.

### Filter and BackdropFilter — `§ 13`

`Filter` is `§ 13.1` on `filter`; `BackdropFilter` is `§ 13.2` on
`backdrop-filter` (not `Backdrop`, which is the `::backdrop` modifier).

<!-- example: filter -->

| Section | Sub-sections | Emits |
| --- | --- | --- |
| `Filter` | `Blur`, `Brightness`, `Contrast`, `DropShadow`, `Grayscale`, `HueRotate`, `Invert`, `Saturate`, `Sepia` | `--tw-<family>:<fn>;filter:<chain>` |
| `BackdropFilter` | the same without `DropShadow`, plus `Opacity` (`§ 12.3`'s fifteen steps) | `--tw-backdrop-<family>:<fn>;backdrop-filter:<chain>` |

**Filters compose.** Every leaf writes its own family's custom property and one
reader, `var(--tw-blur, ) var(--tw-brightness, ) … var(--tw-drop-shadow, )`, so
`[.Filter.Blur.Sm, .Filter.Grayscale.__100]` keeps both — the empty fallbacks make
an unset family contribute nothing. `Blur.None` is `filter:none` (it replaces the
whole chain); `DropShadow.None` empties its own family (`--tw-drop-shadow: `),
as upstream does — the reference's `drop-shadow(none)` is not valid CSS.

The values are the reference's own (`brightness(.5)`, `grayscale(100%)`,
`hue-rotate(90deg)`); the blur lengths and the drop shadows are theme references
(`blur(var(--blur-md))`, `drop-shadow(var(--drop-shadow-md))`) whose values are
`filterEntries()` — compose them with `extendTheme(defaultTheme(), filterEntries())`.
Arbitrary values: `rawFilter("…")` and `rawBackdropFilter("…")`
(`Token.FilterRaw` / `Token.BackdropRaw`).

### Table — `§ 14`

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

### Transition and Animate — `§ 15`

Before front 44 there was no `transition` token anywhere in emilia, which meant
every state front 34 made expressible arrived in **one frame**: a button that
darkens on hover darkened between two frames with nothing in between. There was
also no `animate-spin`, so "something is happening" — the most common piece of
feedback an application gives — had no token at all and needed a hand-written
stylesheet beside emilia.

`Transition` is `§ 15.1`–`§ 15.5` and `Animate` is `§ 15.6`. **36 leaves.**

#### The presets — one token, three declarations

`§ 15.1` is unusual: six of its seven rows are **three declarations from one
utility**. `transition-colors` sets the property list, the timing function and
the duration together. emilia needs no new machinery for that — `tokensToCss`
joins with `;` already — so one leaf answers a `;`-joined string and the
token-to-class mapping stays one-to-one.

| Token | CSS |
| --- | --- |
| `.Transition.None` | `transition-property:none` — the one single-declaration row |
| `.Transition.Base` | the eleven-property list, `var(--ease-out)`, `150ms` |
| `.Transition.All` | `transition-property:all` + the same tail |
| `.Transition.Colors` | `color, background-color, border-color, text-decoration-color, fill, stroke` + the tail |
| `.Transition.Opacity` | `transition-property:opacity` + the tail |
| `.Transition.Shadow` | `transition-property:box-shadow` + the tail |
| `.Transition.Transform` | `transition-property:transform` + the tail |

The bare `transition` utility is `.Transition.Base`, **not** `.Transition.Default`,
for two reasons at once: `default` is in the language's keyword table, and
`Default(inner)` is already a top-level modifier variant of front 34's — the
exact collision the section-head audit exists to catch.

**Note the space after each comma.** `color, background-color, …` is the
reference's own spelling and byte-equality is the gate, so a test counts the
separators as well as spelling the list: eleven properties, ten `, `.

#### `transition-behavior` — the class and the value disagree

| Token | CSS |
| --- | --- |
| `.Transition.Behavior.Normal` | `transition-behavior:normal` |
| `.Transition.Behavior.Discrete` | `transition-behavior:allow-discrete` |

`transition-discrete` emits `allow-discrete`, not `discrete`. It has a test of
its own, asserted in both directions, because it is exactly the row that gets
written from memory and gets written wrong.

#### Duration, delay and easing

`.Transition.Duration.__N` and `.Transition.Delay.__N` over
`{0, 75, 100, 150, 200, 300, 500, 700, 1000}`, emitting
`transition-duration:<N>ms` and `transition-delay:<N>ms`. **Every step carries
its unit, `0ms` included** — a bare `0` is legal CSS for a length and is not
what `§ 15.3` prints. These two are **not** theme lookups, and that is the
reference's call: `§ 15.3` and `§ 15.5` print the milliseconds literally and
upstream has no `--duration-*` namespace.

| Token | CSS |
| --- | --- |
| `.Transition.Ease.Linear` | `transition-timing-function:linear` — a CSS keyword |
| `.Transition.Ease.In` | `transition-timing-function:var(--ease-in)` |
| `.Transition.Ease.Out` | `transition-timing-function:var(--ease-out)` |
| `.Transition.Ease.InOut` | `transition-timing-function:var(--ease-in-out)` |

`ease-linear` is CSS's own keyword; upstream has no `--ease-linear` and emilia
does not invent one.

#### A preset then an override

<!-- example: transition-override -->

Two tokens, two rules, four declarations — and the preset's `150ms` is still in
the output with the `200ms` after it. **List order is declaration order**, so
the later one wins; reversing the two is a different class whose preset now
overrides the override.

#### `transitionEntries()` — upstream's three `--ease-*` values

`defaultTheme()` carries the four `--animate-*` entries and **no `--ease-*`**,
so a project composes them:

<!-- example: transition-entries -->

| Name | Value |
| --- | --- |
| `--ease-in` | `cubic-bezier(0.4, 0, 1, 1)` |
| `--ease-out` | `cubic-bezier(0, 0, 0.2, 1)` |
| `--ease-in-out` | `cubic-bezier(0.4, 0, 0.2, 1)` |

`§ 15.4` prints the three *names* and no value; the cubic-beziers are
upstream v4's `theme.css` (4.3.2), byte for byte. The namespace is front 54's
`Ns.Ease`, so `extendTheme` accepts them and `clearNamespace(th, Ns.Ease)` drops
exactly these three; every rule references the variable and never its value.

#### Animate — a declaration and a block

| Token | CSS | Block |
| --- | --- | --- |
| `.Animate.None` | `animation:none` | none |
| `.Animate.Spin` | `animation:var(--animate-spin)` | `@keyframes spin` |
| `.Animate.Ping` | `animation:var(--animate-ping)` | `@keyframes ping` |
| `.Animate.Pulse` | `animation:var(--animate-pulse)` | `@keyframes pulse` |
| `.Animate.Bounce` | `animation:var(--animate-bounce)` | `@keyframes bounce` |

`animateTokenToSheet` is the **one dispatcher in fronts 41–47 that answers a
`Sheet`** rather than a declaration string, because `animate-spin` is only half
a rule: the other half is the `@keyframes spin` block, which is not a style
rule and cannot be nested inside one. Front 56's `blockSheet(header, body)` and
`Sheet.blocks` carry it, `renderDocument` hoists it **out of every cascade
layer to the end of the document**, and `dedupeBlocks` there is what makes two
spinners on a page one block.

**The keyframes bodies are read out of the theme, not transcribed here.** Front
54's `keyframeEntries()` already carries all four and `renderDocument` already
hoists them; `animationSheet(th, name)` looks the body up through
`keyframeCss(th)`, so there is exactly one copy of that table in the library.
The consequence, and it is asserted: under a theme that carries no body for a
name, the token still emits its declaration and hoists **no** block — which is
also what makes `.Animate.None` and `AnimateRaw` blockless without a special
case.

#### Arbitrary values — `rawTransitionProperty`, `rawAnimate`

<!-- example: transition-raw -->

`Token.TransitionProperty(value)` and `Token.AnimateRaw(value)` are **top-level**
variants, not `Transition.Property(…)` / `Animate.Raw(…)`, because a payload
leaf nested inside an enum section cannot be constructed by any spelling (see
§ `Color.Hex("#abc")` is declared and unconstructible). For `AnimateRaw` that is
not an inconvenience: it is the *only* way to name an animation this library
does not ship, so the nested spelling would have shut the door rather than
narrowed it. The wrappers exist because a leading-dot path followed by a payload
call does not carry the typed-array context either.

`rawAnimate` goes through `declSheet` and **not** through `animateTokenToSheet`:
a custom animation names keyframes emilia does not own, so it hoists no block.

`§ 15` prints no arbitrary-value row; both were measured against upstream v4.
`rawAnimate` is `animation:<value>`, as upstream's `animate-[…]`.
`rawTransitionProperty` writes the property **and** the timing and duration
defaults, as upstream's `transition-[…]` and every preset beside it do:
`transition-property:width;transition-timing-function:var(--ease-out);transition-duration:150ms`.

#### Nothing in `Transition` or `Animate` resolves a timing function

A test walks all **36 leaves** asserting the declaration carries a `:`; carries
neither `cubic-bezier(` nor `infinite`; carries no Tailwind class fragment; and
— for the two ms ladders — ends in `ms`. Each probe has a control that must
fail **and** a control proving it does not fire on correct output:
`var(--animate-spin)` legitimately contains the class name `animate-spin` and
`var(--ease-in-out)` contains `ease-in-out`, so neither is in the fragment list
and both are asserted *not* to trip it.

The walk reads **declarations and not sheets**, deliberately: the
`@keyframes bounce` body legitimately carries `cubic-bezier(0.8,0,1,1)`, and it
is a block, not a declaration. The four bodies are pinned as literals beside it.

`examples/emilia-transitions/` is the worked example: the catalogue, the
preset-then-override ordering as working code, and a submit button whose colours
move over 200ms on hover and which dims and grows a spinner while the form is in
flight.

#### Not declared

`@starting-style`. `§ 15` has six subsections and none of them mentions it, so a
token for it would be written from memory. Front 56's `Sheet.blocks` would carry
it the day the reference does.

### Interact — `§ 17`

Cursor, form controls, pointer events, resize, selection, `will-change`,
touch, scrolling and snapping — one section, 161 leaves.

<!-- example: interact -->

- `cursor-default` is `.Interact.Cursor.Standard`; `accent-auto` is
  `.Interact.AccentAuto`.
- Three class names lie about their value: `.Interact.Resize.Y` is
  `resize:vertical`, `.Resize.X` is `horizontal`, `.WillChange.Scroll` is
  `scroll-position`.
- `.Interact.Scroll.{M,Mx,My,Mt,Mr,Mb,Ml,P,Px,Py,Pt,Pr,Pb,Pl}.__N` (0, 1, 2, 4,
  8) are `spacing(n)`; the axis forms are two declarations, left before right.
- `.Interact.Snap.Type.X` is `scroll-snap-type:x var(--tw-scroll-snap-strictness,
  proximity)`: alone it snaps by proximity, and `.Snap.Strictness.Mandatory` in
  the same list makes it mandatory.
- Colours are top-level variants carrying a palette reference, never a hex:
  `accent(v)`, `caret(v)`, `scrollbarColor(thumb, track)` with
  `paletteVar(family, shade)`.

### Svg and A11y — `§ 18`, `§ 19`

| Token | Emits |
| --- | --- |
| `.Svg.Fill.Current` / `.None` | `fill:currentcolor` / `fill:none` |
| `.Svg.Stroke.Current` / `.None` | `stroke:currentcolor` / `stroke:none` |
| `.Svg.StrokeWidth.__0` / `__1` / `__2` | `stroke-width:N` (unitless) |
| `fillColor(paletteVar("red", "500"))` | `fill:var(--color-red-500)` |
| `strokeColor(v)` / `rawStrokeWidth("3")` | `stroke:<v>` / `stroke-width:3` |
| `.A11y.SrOnly` | upstream's nine declarations (`position:absolute;width:1px;…;border-width:0`) |
| `.A11y.NotSrOnly` | upstream's eight — every `sr-only` property but `border-width` |
| `.A11y.ForcedColorAdjust.Auto` / `.None` | `forced-color-adjust:auto` / `none` |

An icon-only button: the glyph is `[.Svg.Stroke.Current, .Svg.StrokeWidth.__2,
.Svg.Fill.None]`, the label `[.A11y.SrOnly]`.

### Transform — `§ 16`

Ninety-six leaves in one section over sixteen sub-sections: `Rotate` (with a
`Neg` sub-section), `Scale`, `ScaleX`, `ScaleY`, `TranslateX`, `TranslateY`,
`SkewX`, `SkewY`, `Origin`, `Style`, `Backface`, `Perspective`,
`PerspectiveOrigin`, `Zoom` and `Shorthand`. Front 44 shipped
`Transition.Transform`, which names `transition-property:transform` — a
transition over a property no other token could set — and this section is what
makes it mean something.

#### In v4 `rotate`, `scale` and `translate` are properties, not functions

That is the change the whole section rests on. Three tokens in one list are
three declarations in one rule and none overwrites another:

<!-- example: transform-lifted -->

Three properties, so none overwrites another; the pre-1.0.10
`transform:rotate(45deg) scale(1.1)` shape is gone. Scale and translate also
write their axes into `--tw-*` variables, as upstream v4 does, so two axes of
one family compose too.

#### Rotate, and the negative half

| token | CSS |
|---|---|
| `.Transform.Rotate.__0` | `rotate:0deg` |
| `.Transform.Rotate.__1` | `rotate:1deg` |
| `.Transform.Rotate.__45` | `rotate:45deg` |
| `.Transform.Rotate.__90` | `rotate:90deg` |
| `.Transform.Rotate.__180` | `rotate:180deg` |
| `.Transform.Rotate.Neg.__12` | `rotate:calc(12deg * -1)` |

`Neg` is a sub-section and not a sign, because there is no spelling for a
negative numeric leaf — front 35's `Margin.*.Neg` convention, third use. The
five magnitudes are `1`, `12`, `45`, `90`, `180`, and each negates the way
upstream v4 does, by multiplying: `calc(Ndeg * -1)`.

#### Scale — upstream v4's three variables

A step is a **percentage** written into `--tw-scale-x`, `--tw-scale-y` and
`--tw-scale-z`, then read by one `scale:var(--tw-scale-x) var(--tw-scale-y)`;
`ScaleX` / `ScaleY` write their own axis only, so the two compose:

<!-- example: transform-scale -->

The three variables are registered with `@property` (initial value `1`), so an
axis nobody set reads as identity. The reference file's `scale:.5` /
`scale:.5 1` is v3's shape. `.Transform.Zoom.__50` stays `zoom:0.5`, the
reference's bare number.

#### Translate — upstream v4's two variables

A one-axis token writes its axis into `--tw-translate-x` / `--tw-translate-y`
and then reads both, exactly as upstream Tailwind v4 does; the both-axes
`Translate` writes the two variables:

| token | CSS |
|---|---|
| `.Transform.TranslateX.__0` | `--tw-translate-x:0;translate:var(--tw-translate-x) var(--tw-translate-y)` |
| `.Transform.TranslateX.Px` | `--tw-translate-x:1px;translate:var(--tw-translate-x) var(--tw-translate-y)` |
| `.Transform.TranslateX.__1` | `--tw-translate-x:calc(var(--spacing) * 1);translate:…` |
| `.Transform.TranslateX.Half` | `--tw-translate-x:50%;translate:…` |
| `.Transform.TranslateX.Full` | `--tw-translate-x:100%;translate:…` |
| `.Transform.TranslateY.Half` | `--tw-translate-y:50%;translate:…` |
| `.Transform.TranslateY.Neg.__2` | `--tw-translate-y:calc(var(--spacing) * -2);translate:…` |
| `.Transform.TranslateX.Neg.Px` | `--tw-translate-x:-1px;translate:…` |
| `.Transform.TranslateX.Neg.Half` | `--tw-translate-x:calc(calc(1 / 2 * 100%) * -1);translate:…` |
| `.Transform.TranslateX.Neg.Full` | `--tw-translate-x:-100%;translate:…` |

`Neg` is a sub-section (`Px`, `1`, `2`, `Half`, `Full`), not a sign: a numeric
leaf has no sign (decision 314), the same shape as `Rotate.Neg` and
`Margin.*.Neg`. The values are Tailwind 4.3.2's for `-translate-x-px`,
`-translate-y-2`, `-translate-x-1/2` and `-translate-y-full`.
| `.Transform.Translate.Half` | `--tw-translate-x:50%;--tw-translate-y:50%;translate:…` |

The axis a class does not set reads `0`: every translate class carries
upstream's `@property` registrations (`@property --tw-translate-x{syntax:"*";
inherits:false;initial-value:0}`, and `-y`, `-z`), written once per document
after the layers, and the flush writes upstream's fallback for an engine
without `@property` — `@layer properties;` declared before every other layer and
`@layer properties{@supports (…){*,::before,::after,::backdrop{--tw-translate-x:0;…}}}`
at the end. So `[.TranslateX.Half, .TranslateY.Half]` moves an element
diagonally.

#### Skew — upstream v4's variable and chain

`§ 16.6`'s "Propriedade CSS" column says `skew-x: 3deg`. That is not a
registered CSS property. Upstream writes the axis into a variable and a chain
of five variables into `transform`, and so does emilia:

<!-- example: transform-skew -->

An unset variable is nothing (the empty fallback), so **two skews in one rule
compose**. Each skew class registers the chain's five variables with
`@property` (no initial value).

#### Origin, style and backface

`.Transform.Origin.*` is the nine values of `§ 16.8`; a corner is two keywords
(`transform-origin:top right`, never `top-right`). `.Transform.Style.Flat` and
`.Transform.Style.Preserve3d` are `§ 16.9` — note that the Tailwind class is
`transform-3d` and the value is `preserve-3d`, which is why the leaf is named
after the value. `.Transform.Backface.{Visible,Hidden}` is `§ 16.1`.

#### Perspective — a theme namespace

| token | CSS | theme entry |
|---|---|---|
| `.Transform.Perspective.None` | `perspective:none` | — (a CSS keyword) |
| `.Transform.Perspective.Dramatic` | `perspective:var(--perspective-dramatic)` | `100px` |
| `.Transform.Perspective.Near` | `perspective:var(--perspective-near)` | `300px` |
| `.Transform.Perspective.Normal` | `perspective:var(--perspective-normal)` | `500px` |
| `.Transform.Perspective.Midrange` | `perspective:var(--perspective-midrange)` | `800px` |
| `.Transform.Perspective.Distant` | `perspective:var(--perspective-distant)` | `1200px` |

`defaultTheme()` does not carry the namespace, so compose it:

<!-- example: transform-perspective-theme -->

Like front 44's `--ease-*`, **none of these five values is provisional**:
`§ 16.2` prints the variable *and* its length on every row.
`.Transform.PerspectiveOrigin.{Center,Top,Bottom,Left,Right}` is `§ 16.3`.

#### The `transform` shorthand — upstream v4's rows

`.Transform.Shorthand.None` is `transform:none`. `.Cpu` (`transform` /
`transform-cpu`) is the skew chain, and `.Gpu` puts `translateZ(0)` in front of
it:

```text
transform:translateZ(0) var(--tw-rotate-x,) var(--tw-rotate-y,) var(--tw-rotate-z,) var(--tw-skew-x,) var(--tw-skew-y,)
```

A `.Cpu` beside a `.SkewX.__3` therefore keeps the skew. `§ 16.7`'s
`translate(…) rotate(…) scaleX(…)` rows are v3's and are not emitted.

#### Arbitrary values — `rawRotate`, `rawTranslate`

<!-- example: transform-raw -->

`rotate-[17deg]` is in the reference (`§ 16.4`'s HTML example); the translate
hatch is **provisional** — `§ 16` prints no arbitrary translate row — and exists
because a translate the five steps do not name has no other spelling. It writes
both axes and reads neither variable.

Both are top-level `Token` variants for the reason every escape hatch in emilia
is: a payload leaf nested inside a section cannot be constructed. The wrappers
exist because a leading-dot path followed by a payload call does not carry the
typed-array context, so `[.TransformRotateRaw("17deg")]` does not parse.

#### Nothing in `Transform` resolves a length

A test walks **94 leaves** asserting the declaration carries a `:`; carries no
`rem` and no `px`; carries no Tailwind class fragment; and — for rotate and skew
— carries its `deg`. A 96-way distinctness walk adds the two `Px` leaves back
and pins `§ 16.5`'s one legitimate collision by name. Each probe has a control
that must fail **and** a control proving it does not fire on correct output:
`var(--perspective-near)` contains the class name `perspective-near`, and
`var(--tw-scale-x)` contains `scale-x`, so every fragment in the list carries
its numeric or keyword suffix.

The two exceptions to the length rule are `TranslateX.Px` and `TranslateY.Px`,
whose `1px` is the reference's own literal value. They are held out of the walk
and asserted from the other side.

`examples/emilia-transforms/` is the worked example: the catalogue, a card that
lifts and grows and deepens its shadow on hover, and a chevron that flips 180°
when its disclosure opens.

#### Not declared

`rotate-x-*`, `rotate-y-*`, `rotate-z-*`, `translate-z-*`, `scale-z-*` and an
unaxed `translate-*`. `§ 16` has eleven subsections and none of them enumerates
a 3-D axis variant or a both-axes translate, so tokens for them would be written
from memory. The rest of the 3-D surface — `transform-style`, `backface-*` and
the perspective family — **is** in the reference and is shipped.

### Modifiers — the variant table

A modifier is the only way a token reaches a state, a breakpoint or a
pseudo-element. Each one carries a `Token[]` payload and is **not** a block
nested inside the class body — it is a `Variant` (an at-rule and a selector
template with exactly one `&`), and the tokens it carries become **sibling
rules** hoisted out of the class with their own selector and at-rule.

<!-- example: modifier-dark -->

Modifiers nest, and the OUTER one is outermost in the selector and in the
at-rule list alike — which is how a `dark:md:hover:` chain reads upstream:

<!-- example: modifier-nesting -->

A breakpoint RANGE is nesting too, not a variant of its own — upstream's
`md:max-xl:` is `Token.Md([Token.MaxXl([…])])`. Every breakpoint reads the
theme's `--breakpoint-*` entry, both ways round, so overriding the ladder
moves the queries and the class hashes with it.

**Breakpoints — min-width, read from the theme's `--breakpoint-*` ladder**

| upstream | emilia | CSS |
| --- | --- | --- |
| `sm:` | `Token.Sm(inner)` | `@media (width >= 40rem){…}` |
| `md:` | `Token.Md(inner)` | `@media (width >= 48rem){…}` |
| `lg:` | `Token.Lg(inner)` | `@media (width >= 64rem){…}` |
| `xl:` | `Token.Xl(inner)` | `@media (width >= 80rem){…}` |
| `2xl:` | `Token.X2xl(inner)` | `@media (width >= 96rem){…}` |

**Breakpoints — max-width, the same ladder read the other way**

| upstream | emilia | CSS |
| --- | --- | --- |
| `max-sm:` | `Token.MaxSm(inner)` | `@media (width < 40rem){…}` |
| `max-md:` | `Token.MaxMd(inner)` | `@media (width < 48rem){…}` |
| `max-lg:` | `Token.MaxLg(inner)` | `@media (width < 64rem){…}` |
| `max-xl:` | `Token.MaxXl(inner)` | `@media (width < 80rem){…}` |
| `max-2xl:` | `Token.MaxX2xl(inner)` | `@media (width < 96rem){…}` |

**Dark mode and the other media features**

| upstream | emilia | CSS |
| --- | --- | --- |
| `dark:` | `Token.Dark(inner)` | `@media (prefers-color-scheme: dark){…}` |
| `print:` | `Token.Print(inner)` | `@media print{…}` |
| `portrait:` | `Token.Portrait(inner)` | `@media (orientation: portrait){…}` |
| `landscape:` | `Token.Landscape(inner)` | `@media (orientation: landscape){…}` |
| `motion-safe:` | `Token.MotionSafe(inner)` | `@media (prefers-reduced-motion: no-preference){…}` |
| `motion-reduce:` | `Token.MotionReduce(inner)` | `@media (prefers-reduced-motion: reduce){…}` |
| `contrast-more:` | `Token.ContrastMore(inner)` | `@media (prefers-contrast: more){…}` |
| `contrast-less:` | `Token.ContrastLess(inner)` | `@media (prefers-contrast: less){…}` |
| `forced-colors:` | `Token.ForcedColors(inner)` | `@media (forced-colors: active){…}` |

**Interaction state**

| upstream | emilia | CSS |
| --- | --- | --- |
| `hover:` | `Token.Hover(inner)` | `@media (hover: hover){&:hover{…}}` |
| `focus:` | `Token.Focus(inner)` | `&:focus{…}` |
| `focus-within:` | `Token.FocusWithin(inner)` | `&:focus-within{…}` |
| `focus-visible:` | `Token.FocusVisible(inner)` | `&:focus-visible{…}` |
| `active:` | `Token.Active(inner)` | `&:active{…}` |
| `visited:` | `Token.Visited(inner)` | `&:visited{…}` |
| `target:` | `Token.Target(inner)` | `&:target{…}` |
| `open:` | `Token.Open(inner)` | `&:is([open], :popover-open, :open){…}` |
| `inert:` | `Token.Inert(inner)` | `&:is([inert], [inert] *){…}` |

**Form state**

| upstream | emilia | CSS |
| --- | --- | --- |
| `disabled:` | `Token.Disabled(inner)` | `&:disabled{…}` |
| `enabled:` | `Token.Enabled(inner)` | `&:enabled{…}` |
| `checked:` | `Token.Checked(inner)` | `&:checked{…}` |
| `indeterminate:` | `Token.Indeterminate(inner)` | `&:indeterminate{…}` |
| `default:` | `Token.Default(inner)` | `&:default{…}` |
| `optional:` | `Token.Optional(inner)` | `&:optional{…}` |
| `required:` | `Token.Required(inner)` | `&:required{…}` |
| `valid:` | `Token.Valid(inner)` | `&:valid{…}` |
| `invalid:` | `Token.Invalid(inner)` | `&:invalid{…}` |
| `user-valid:` | `Token.UserValid(inner)` | `&:user-valid{…}` |
| `user-invalid:` | `Token.UserInvalid(inner)` | `&:user-invalid{…}` |
| `in-range:` | `Token.InRange(inner)` | `&:in-range{…}` |
| `out-of-range:` | `Token.OutOfRange(inner)` | `&:out-of-range{…}` |
| `placeholder-shown:` | `Token.PlaceholderShown(inner)` | `&:placeholder-shown{…}` |
| `autofill:` | `Token.Autofill(inner)` | `&:autofill{…}` |
| `read-only:` | `Token.ReadOnly(inner)` | `&:read-only{…}` |

**Structural position**

| upstream | emilia | CSS |
| --- | --- | --- |
| `first:` | `Token.First(inner)` | `&:first-child{…}` |
| `last:` | `Token.Last(inner)` | `&:last-child{…}` |
| `only:` | `Token.Only(inner)` | `&:only-child{…}` |
| `odd:` | `Token.Odd(inner)` | `&:nth-child(odd){…}` |
| `even:` | `Token.Even(inner)` | `&:nth-child(even){…}` |
| `first-of-type:` | `Token.FirstOfType(inner)` | `&:first-of-type{…}` |
| `last-of-type:` | `Token.LastOfType(inner)` | `&:last-of-type{…}` |
| `only-of-type:` | `Token.OnlyOfType(inner)` | `&:only-of-type{…}` |
| `empty:` | `Token.Empty(inner)` | `&:empty{…}` |
| `nth-N:` | `Token.Nth(index, inner)` | `&:nth-child(3){…}` |
| `nth-last-N:` | `Token.NthLast(index, inner)` | `&:nth-last-child(5){…}` |

**Pseudo-elements**

| upstream | emilia | CSS |
| --- | --- | --- |
| `before:` | `Token.Before(inner)` | `&::before{…}` |
| `after:` | `Token.After(inner)` | `&::after{…}` |
| `first-letter:` | `Token.FirstLetter(inner)` | `&::first-letter{…}` |
| `first-line:` | `Token.FirstLine(inner)` | `&::first-line{…}` |
| `placeholder:` | `Token.Placeholder(inner)` | `&::placeholder{…}` |
| `file:` | `Token.File(inner)` | `&::file-selector-button{…}` |
| `marker:` | `Token.Marker(inner)` | `& *::marker{…}`, `&::marker{…}`, and the same two for `::-webkit-details-marker` |
| `selection:` | `Token.Selection(inner)` | `& *::selection{…}`, `&::selection{…}` |
| `backdrop:` | `Token.Backdrop(inner)` | `&::backdrop{…}` |

**Parent state — the `.group` class is the consumer's, never emilia's**

| upstream | emilia | CSS |
| --- | --- | --- |
| `group-hover:` | `Token.GroupHover(inner)` | `&:is(:where(.group):hover *){…}` |
| `group-focus:` | `Token.GroupFocus(inner)` | `&:is(:where(.group):focus *){…}` |
| `group-active:` | `Token.GroupActive(inner)` | `&:is(:where(.group):active *){…}` |
| `group-visited:` | `Token.GroupVisited(inner)` | `&:is(:where(.group):visited *){…}` |
| `group-disabled:` | `Token.GroupDisabled(inner)` | `&:is(:where(.group):disabled *){…}` |
| `group-open:` | `Token.GroupOpen(inner)` | `&:is(:where(.group):is([open], :popover-open, :open) *){…}` |

**Sibling state — the `.peer` class is the consumer's, never emilia's**

| upstream | emilia | CSS |
| --- | --- | --- |
| `peer-hover:` | `Token.PeerHover(inner)` | `&:is(:where(.peer):hover ~ *){…}` |
| `peer-focus:` | `Token.PeerFocus(inner)` | `&:is(:where(.peer):focus ~ *){…}` |
| `peer-active:` | `Token.PeerActive(inner)` | `&:is(:where(.peer):active ~ *){…}` |
| `peer-checked:` | `Token.PeerChecked(inner)` | `&:is(:where(.peer):checked ~ *){…}` |
| `peer-invalid:` | `Token.PeerInvalid(inner)` | `&:is(:where(.peer):invalid ~ *){…}` |
| `peer-required:` | `Token.PeerRequired(inner)` | `&:is(:where(.peer):required ~ *){…}` |
| `peer-disabled:` | `Token.PeerDisabled(inner)` | `&:is(:where(.peer):disabled ~ *){…}` |
| `peer-placeholder-shown:` | `Token.PeerPlaceholderShown(inner)` | `&:is(:where(.peer):placeholder-shown ~ *){…}` |

**Writing direction and descent**

| upstream | emilia | CSS |
| --- | --- | --- |
| `rtl:` | `Token.Rtl(inner)` | `&:where(:dir(rtl), [dir="rtl"], [dir="rtl"] *){…}` |
| `ltr:` | `Token.Ltr(inner)` | `&:where(:dir(ltr), [dir="ltr"], [dir="ltr"] *){…}` |
| `*:` | `Token.Children(inner)` | `:is(& > *){…}` |
| `**:` | `Token.Descendants(inner)` | `:is(& *){…}` |

**The priority wrapper — not a variant, a flag on every rule it wraps**

| upstream | emilia | CSS |
| --- | --- | --- |
| `…!` | `Token.Important(inner)` | `!important` on every declaration it wraps |

**Named groups and peers — `group/card`, `peer/field`**

`Token.GroupNamed(name, inner)` and `Token.PeerNamed(name, inner)` name the
`.group` / `.peer` class of the unnamed state tokens in `inner`; every state
above is available named, and any other token in `inner` is folded unchanged.

<!-- example: named-groups -->

The consumer's markup carries `class="group/card"` / `class="peer/foo"`. A name
may contain only letters, digits, `-` and `_`; anything else is a panic.

`.group` and `.peer` are classes the **consumer's markup** carries: emilia
emits the selector that reads them and never the class itself.

`Important` is the one row that is not a variant — it adds no selector and
no at-rule, it sets the `!important` flag on every rule it wraps, which is
upstream's per-utility `!` suffix.

`examples/emilia-modifiers/` is the worked example: a responsive navigation
bar, a peer-driven form field, a self-striping table, and one panel rendered
under all three dark-mode strategies.

## The runtime — `emilia(tokens)` and `flush()`

- `emilia(tokens: Token[]) -> string`
  - Maps each token through `tokenToSheet`, merges the sheets in list order,
    names the class `e_` + `hash.contentHash` of the result's rules as
    the document writes them (`classRules`, the class written `\u{1}`),
    registers `(e_<hash>, payload)` on the per-render `Stylesheet`, returns
    the class name.
- `emiliaWith(tokens: Token[], th: Theme) -> string`
  - The same, under an explicit theme. `emilia(tokens)` is
    `emiliaWith(tokens, defaultTheme())`. The theme is an input: a `Md`
    modifier carries the theme's `--breakpoint-md`, so two themes give two
    classes for the same token list.
- `flush() -> string`
  - Drains the `Stylesheet` and renders the **document** — the `@layer`
    statement, the theme layer, the base layer, the components layer, the
    utilities layer and the `@keyframes` blocks — AND clears the cell.
    Per-render contract: two consecutive `flush()` calls emit two
    independent documents; the second has no `@layer utilities` body if no
    `register` happened between them.
- `flushWith(o: Options) -> string`
  - The same, under explicit options. `flush()` is
    `flushWith(defaultOptions())`. See § The cascade and the output.

### Stable hashes — sites collapse

Identical token lists on different elements share one class:

<!-- example: stable-hashes -->

## The theme

A theme is a **flat list of CSS custom properties**, not nineteen record
fields. That is what CSS itself has, and it is the only shape in which
"clear one namespace" and "clear everything" are ordinary values rather than
nineteen more functions.

<!-- example: theme-api -->

| Type | What it is |
| --- | --- |
| `ThemeEntry(name, value)` | one custom property — `name` carries its `--` prefix |
| `Theme(entries, keyframes, darkMode)` | the flat set, the keyframes bodies, and the dark-mode strategy |
| `Ns` | the nineteen namespaces: `Color`, `Font`, `Text`, `FontWeight`, `Tracking`, `Leading`, `Breakpoint`, `Container`, `Spacing`, `Radius`, `Shadow`, `InsetShadow`, `DropShadow`, `Blur`, `Perspective`, `Aspect`, `Ease`, `Animate`, `Keyframes` |
| `DarkMode` | `Media`, `Class(name)`, `Attribute(name, value)` |

| Function | What it answers |
| --- | --- |
| `nsPrefix(ns) -> string` | the namespace's prefix — `--color-`, `--font-`, …, `@keyframes ` |
| `allNamespaces() -> Ns[]` | the nineteen, in declaration order |
| `defaultTheme() -> Theme` | emilia's stock theme |
| `emptyTheme() -> Theme` | a theme with nothing in it — the `--*: initial` reset |
| `extendTheme(th, entries) -> Theme` | add entries; a name already present is **overridden in place** |
| `clearNamespace(th, ns) -> Theme` | drop one namespace — the `--color-*: initial` reset |
| `namespace(th, ns) -> ThemeEntry[]` | the entries of one namespace, in the theme's order |
| `themeValue(th, name) -> string` | the literal value, or `""` when the theme does not carry the name |
| `themeVar(name) -> string` | the reference form, `var(--name)` — what a utility emits |

`--spacing` is a **single variable**, so `nsPrefix(Ns.Spacing)` is `--spacing`
with no trailing dash.

<!-- example: theme-brand -->

### The name is `extendTheme`, not `extend`

`extend` is a **language keyword** (`Name extend Type { … }`, the type-extension
block), so `fn extend(…)` does not parse. Every front that composes a theme
writes `extendTheme`.

### `extendTheme` refuses an unknown namespace

An entry whose name starts with none of the nineteen prefixes is **refused**,
loudly, naming the offending name. There is no permissive mode and no argument
that relaxes it: an unknown prefix is a typo or a namespace this library does
not have, and both are errors. A variable that is silently absent is debugged as
a cascade bug days later, in a browser.

<!-- example: theme-unknown-namespace -->

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

<!-- example: spacing-functions -->

A negative whole step needs no second function (`spacing(-4)`). A negative HALF
step does: `spacingHalf` takes the whole part as an `i32`, and an `i32` has no
negative zero, so `-0.5` could not be spelled through it — the sign lives in
`spacingNegHalf`'s name instead. `spacing` takes an `i32`, not an `f64`, so the
emitted string never depends on a backend's float formatting; the fractional
steps are a closed set that the two half functions cover exactly.

### Rendering a theme

| Function | What it answers |
| --- | --- |
| `themeCss(th) -> string` | the `:root` body — `name:value` joined with `;` |
| `keyframeCss(th) -> ThemeEntry[]` | the `@keyframes` bodies, which cannot sit inside `:root` |
| `darkAtRule(th) -> string` | the at-rule a dark rule nests inside, or `""` |
| `darkSelector(th) -> string` | the selector a dark rule is written against |
| `withDarkMode(th, mode) -> Theme` | swap the strategy, change nothing else |

The block is **always the whole theme**. Upstream emits only the variables a
build used, and `@theme static` emits all of them; emilia's behaviour is the
second, because tree-shaking would need a whole-program pass over every
`emilia()` call site and emilia hashes per call site.

Entry order is the theme's own, and it matters: emilia's class names are content
hashes, so a reordered theme is a different document for the same input.

A keyframes entry carries the bare animation name and a brace-balanced body, so
one block is written `nsPrefix(Ns.Keyframes) + name + value` —
`@keyframes spin{to{transform:rotate(360deg)}}` — and nobody spells the at-rule
by hand.

| Strategy | `darkAtRule` | `darkSelector` |
| --- | --- | --- |
| `DarkMode.Media` | `@media (prefers-color-scheme: dark)` | `&` |
| `DarkMode.Class(name: "dark")` | `""` | `&:where(.dark, .dark *)` |
| `DarkMode.Attribute(name: "data-theme", value: "dark")` | `""` | `&:where([data-theme=dark], [data-theme=dark] *)` |

`Class` and `Attribute` carry the whole strategy in the selector, which is why
their at-rule is empty. The `Dark` token that consumes these is front 34's.

### The colour palette

`defaultTheme()` carries `--color-black` and `--color-white` and nothing else.
The 286 numeric values are front 33's data, handed over as
`paletteEntries() -> ThemeEntry[]` and composed by the consumer:

<!-- example: palette-entries -->

It is a **list, not a rendered block**, and that is the point: a project that
already imports upstream's own theme leaves it out and still uses every colour
token, because a token emits `var(--color-red-500)` and whoever declares that
variable is the consumer's call. `emilia(...)` emits no `@theme` block of its
own, at any size of token list.

The values are transcribed from upstream `tailwindcss` **4.3.2**'s
`theme.css`. The reference prints exactly two of them
(`--color-red-500`, `--color-blue-500`) in the decimal-lightness spelling
`oklch(0.637 0.237 25.331)`; upstream writes the same colour as
`oklch(63.7% 0.237 25.331)`. Both are the same lightness in OKLCH; emilia
takes upstream's, so the emitted `@theme` block is byte-equal with the one a
project would otherwise import.

### A theme is a module

Upstream shares a theme between projects by importing a CSS file. In botopink a
theme is a **function in a module**, so sharing one is an ordinary package
dependency: a package exports `brandTheme() -> Theme` or a bare
`entries() -> ThemeEntry[]`, and the consumer composes it with `extendTheme`.
[`examples/emilia-theme/`](../examples/emilia-theme/) is the worked example.

<!-- example: theme-module -->

## The cascade and the output

A token used to lower to a **declaration string**, and a modifier wrapped that
string in braces, so a whole class was one nested block. That shape can only
express what fits inside one class body. A token lowers to a **`Sheet`** now, and
a sheet is a list of rules that can sit anywhere in the document.

<!-- example: sheet-api -->

| Type | What it is |
| --- | --- |
| `Rule(layer, atRules, selector, declarations, important)` | one style rule — `atRules` outermost-first, `declarations` `;`-joined with no braces around it |
| `Block(header, body)` | a rule that is **not** a style rule: `@keyframes spin` plus its brace-balanced body |
| `Sheet(rules, blocks)` | what a token list produces |
| `Variant(atRule, selector)` | what a modifier is — an at-rule and a selector template, either of which may be empty |
| `Options(theme, base, prefix, important, layers)` | the build-level knobs |

### A selector is a nesting template

`selector` carries **exactly one `&`**, and `&` stands for the class. That one
field covers every variant there is, because each is a template with one `&`:

<!-- example: variant-templates -->

A selector with **no** `&` is a **literal** selector — that is how the theme
writes `:root` and how a reset writes `html` — and the class name, and therefore
the prefix, never reaches it. A selector with **two or more** `&` is **refused**,
naming the selector. There is no permissive mode and no argument that relaxes it:
with none the variant replaces the rule it was meant to wrap, and with two it
duplicates it, and both are stylesheets that are silently wrong in a browser.

### Nesting runs inner-`&`-first

`nestVariant(s, v)` wraps a sheet in a variant, exactly as CSS nesting does:
the **inner** rule's `&` is what the **outer** variant's selector replaces, and
the outer variant's at-rule is prepended, so the outer modifier is outermost on
both halves.

<!-- example: nest-variant -->

Blocks pass through untouched — an at-rule does not wrap a keyframes rule.

### Building a sheet

| Function | What it answers |
| --- | --- |
| `emptySheet()` | no rules, no blocks |
| `declSheet(decls)` | one `utilities` rule on the bare `&`; **`declSheet("")` is `emptySheet()`** |
| `staticSheet(layer, selector, decls)` | one rule whose selector is literal |
| `blockSheet(header, body)` | one `@keyframes` block and no rule |
| `mergeSheet(a, b)` | rules then blocks, order preserved — token order is class identity |
| `declarationsOf(s)` | every rule's declaration string, in order |
| `markImportant(s)` | set `important` on every rule; rendering appends `!important` per **declaration** |
| `layerNames()` | `["theme", "base", "components", "utilities"]` — the cascade order, written once |

### Options, and what wins

`renderRule(className, r, o)` renders one rule and `renderDocument(raw, o)` the
whole `<style>` document. The last rule in the stylesheet wins, so the order is
pinned rather than inherited from a `Map`:

1. `@layer theme, base, components, utilities;` when `layers` is on;
2. the **theme** layer — the custom-property block as a `:root` rule;
3. the **base** layer — `o.base`, front 55's reset. It is **opt-in**: the
   default is `withBase(o, [])`, a deliberate inversion of upstream's default;
4. the **components** layer;
5. the **utilities** layer — registered classes in **registration** order;
   within one class, the tokens in the order they were listed, and within one
   class the rules with **no at-rules before** the rules with at-rules, so a
   `md:` override beats the unconditioned utility on a mobile-first read;
6. the `@keyframes` blocks, **outside every layer**, deduplicated by header.
   Keyframes are not subject to the cascade, so their placement is a formatting
   choice; it is written down so it is not re-litigated.

`withLayers(o, false)` emits **no `@layer` token at all** and the same rules in
the same order, so the cascade then rests on document order alone.

`withPrefix(o, "tw_")` renders `.tw_e_1{…}`. emilia's class names are content
hashes over `[a-z0-9_]`, so a prefix is a plain concatenation: upstream's escaped
`.tw\:text-red-500` form has no analogue here, because emilia has no literal
class names to escape. That divergence is intentional.

`withImportant(o, true)` appends `!important` to every declaration of every rule,
the same thing `markImportant` does to one sheet.

[`examples/emilia-cascade/`](../examples/emilia-cascade/) is the worked example:
one card whose hover is a sibling rule, whose breakpoint is a hoisted `@media`
read from the theme, whose reset arrives through `Options`, and whose document
is layered.

### The codec

A host cell stores one string per class, and a `Sheet` is a record tree, so
`encodeSheet`/`decodeSheet` carry it through: records joined by `"\n"` and tagged
`R`/`B`, fields by `"\t"`, the `atRules` list by `"\r"`. The encoding is what the cell
stores; it is not what is hashed — a class name is `e_` + `hash.contentHash` of
`classRules(sheet)`, the sheet's rules as the document writes them with the class written
`\u{1}` (the text `styled` hashes for a component, decision 367), so a class name is still a
pure function of its sheet.

None of the three characters can appear in a rendered declaration. That is an
assumption, so it is **checked** and not assumed: `carriesSeparator(s)` is an
ordinary value, and the suite walks the dispatcher output and the theme's own
strings through it.

## Deviations

Where emilia does not render a Tailwind 4.3.2 feature as a token (decision 401);
the escape hatch is `arbSel` (see "Arbitrary values").

- **Named `has` / `not` / ARIA / data-attribute / `in` variants** have no named
  tokens; write the selector with `arbSel`:

  <!-- example: deviations-arbsel -->

- **`@theme inline` is not supported.** Every theme reference renders
  `var(--x)`; there is no render mode that resolves the value into each site.

## What's coming (v0.beta.21+)

The spec authors a richer surface that v0 does not yet ship:

- `#[emilia([.Pad.All.4, .Bg.White])] div([…])` — annotation on
  builder, generic rakun-bpp hook.
- `<div [emilia]={[.Pad.All.4, .Bg.White]}>` — `[name]={expr}`
  attribute inside the `html """…"""` DSL, generic rakun-bpp hook.
- Nested section paths (`.Color.Red.500`, `.Pad.X.4`) — gated on the
  `enum-sections` language extension. v0's flat variant names
  (`ColorRed500`, `PadX4`) re-shape into the section paths when
  `enum-sections` lands.
- erlang/beam port for the `Stylesheet` host cell — same surface, swap
  the `Map` for `persistent_term` or an Agent.

The intent + the comptime expansion model live in the spec at
[`specs/1.0.10-beta/05-emilia/README.md`](../../../specs/1.0.10-beta/05-emilia/README.md);
the AGENTS.md tracks the deferred items and the maintainer rules.
