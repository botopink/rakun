# Colour

> Package: [`rakun-stylesheet`](../docs.md) · index: [`../../docs.md`](../../docs.md)

## Color — the palette

Twenty-six families of eleven shades, and **the token emits a reference, not a
value**:

{color-palette/src/main.bp}

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

## Bg.Color — the same palette on `background-color`

{bg-color/src/main.bp}

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

{bg-legacy/src/main.bp}

## Bg — the rest of the background, `§ 10.1`–`§ 10.8`

Seven keyword sub-sections sit beside `Bg.Color`. Each is one declaration, and
none of them resolves a length or reads the theme.

{bg-keywords/src/main.bp}

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

## Gradient — `§ 10.4`

Gradients are their own top-level section, not a sub-section of `Bg`. The stop
colours are not `background-image` at all — they are custom properties the
gradient reads — so nesting them under `Bg.Image` would put three properties
under one name; and a stop is a four-segment path already.

**`To` is the direction. `Stop` is the terminal colour.** Tailwind spells both
with the word `to` (`bg-gradient-to-r` and `to-pink-500`) while they set
unrelated things; rakun-stylesheet does not.

{gradient-direction/src/main.bp}

A corner is **two keywords** — `to top right`, never `to top-right` — and there
is exactly one space after the comma. The eight phrases are spelled in one
place in `emilia.bp`, so adding a direction is one arm.

### The stops

`From`, `Via` and `Stop` each carry the **whole of front 33's grid** — the 26
families over eleven shades, plus `White`, `Black`, `Transparent`, `Current`
and `Inherit`. The colour half is `paletteVar(family, shade)`, the same
function `.Bg.Color.*` calls, so a stop and a background reference ONE custom
property by construction:

{gradient-stops/src/main.bp}

A full gradient is a direction and two or three stops in one list:

{gradient-full/src/main.bp}

**Token order is load-bearing here**, and deliberately so. `Via` writes a
three-stop list and `From` a two-stop one; whichever is listed LAST wins, which
is how a `From` + `Via` + `Stop` triple ends up with the three-colour list.
`Stop` writes no list at all — if it did, it would overwrite `Via`'s.

### What the stop shape does and does not take from upstream

The three custom-property names are upstream's, checked against it:
`--tw-gradient-from`, `--tw-gradient-via`, `--tw-gradient-to`, read by
`var(--tw-gradient-stops)` in the direction.

The **composition** is simpler than upstream's on purpose. Tailwind v4 threads
four position variables through the list and gives `via-*` its own
`--tw-gradient-via-stops`, and both rest on `@property` registration for their
defaults. rakun-stylesheet registers no `@property` for them, and colour-stop positions
(`from-10%`) are not tokens here, so copying that shape would emit a list that
is invalid at computed-value time in every browser.

What is kept is the part that makes the simplification correct: upstream
registers `#0000` as each stop's default, and rakun-stylesheet writes that as a
`var(…, transparent)` **fallback**. So `.Gradient.From.Indigo.500` on its own
still paints indigo → transparent rather than resolving to nothing.

Radial and conic gradients (`bg-radial`, `bg-conic`), the interpolation
suffixes (`bg-linear-to-r/oklch`) and colour-stop positions (`from-10%`) are
**not** tokens: a radial gradient is a different function with a position
argument, and specifying it from memory would be guessing.

## `Color.Hex("#abc")` is declared and unconstructible

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
colour rakun-stylesheet's enum does not carry formats through the same functions.

## Alpha — opacity, upstream's `/N` suffix

{alpha/src/main.bp}

`bg-red-500/50` is a **wrapper**, not a leaf. Opacity cannot hang under the
family — the shade is already the leaf, and a second numeric level would
multiply the grid to 26 × 11 × 21 — and a payload leaf nested inside a section
has no constructible spelling, so `Alpha` is a top-level variant with a
builtin-typed field, the shape `Hover(inner: Token[])` already has.

It rewrites the VALUE of every declaration its inner tokens produce, rule by
rule, so the selector and at-rule of a modifier inside it survive and it
composes in either order:

{alpha-modifier-order/src/main.bp}

A **non-colour** token is rewritten too, and the result is meaningless CSS
(`font-weight:color-mix(in oklab, bold 50%, transparent)`). That is
deliberate: dropping the declaration silently would hide the mistake, and one
a browser discards is visible in devtools the moment it is looked for.
