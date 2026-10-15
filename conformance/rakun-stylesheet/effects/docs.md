# Effects

> Package: [`rakun-stylesheet`](../docs.md) · index: [`../../docs.md`](../../docs.md)

## Effect, Blend and Mask — `§ 12`

Three sections, one hundred and two leaves, and the only place rakun-stylesheet ever
shipped CSS a browser throws away.

### The defect, stated plainly

`.Effect.Shadow.Md` used to emit **`box-shadow:md`**. That is the Tailwind
class suffix in the position a CSS value belongs; a browser discards the whole
declaration, so a card that asked for a shadow rendered flat. All four of
`Sm`/`Md`/`Lg`/`Xl` did it, and the only assertion that touched the family
pinned the wrong string. The four leaf **names** did not move, so nothing
that compiled before stops compiling; what they emit is the fix.

{effect-shadow-fix/src/main.bp}

### Shadows

{effect-shadow/src/main.bp}

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

### Opacity

Twenty-one steps, each upstream v4's **percentage** — `opacity:60%`, where the
reference prints the v3 fraction `opacity:0.6`.

{effect-opacity/src/main.bp}

A numeric leaf is three spellings for one thing: bare digits in the
declaration, `.Effect.Opacity.60` in expression position, `__60` in a `case`
pattern.

`§ 12.3` prints fifteen steps. Six more — `15`, `35`, `45`, `55`, `65`, `85` —
are declared and confirmed against upstream's compiled `opacity-<n>`, which the
reference carries no row for.

### Blend modes

`mix-blend-mode` blends an element with what is **behind** it;
`background-blend-mode` blends an element's own background layers with **each
other**. `§ 12.5` says in one sentence that the two take the same seventeen
values, which is why they are two sub-sections of one section.

{blend/src/main.bp}

The two value tables are written twice, because two enum types cannot share a
`case`. A test strips the property name off each side and asserts the seventeen
values are **equal, in order**, so a typo in one and not the other reddens here
rather than in a browser.

### Masks

Nine properties, nine sub-sections, every value a CSS keyword. Nothing in
`Mask` reads the theme.

{mask/src/main.bp}

**The class suffix is not the CSS value.** `mask-clip-border` sets
`border-box`; a transcription that copied the suffix across would give
`mask-clip:border`, which is the same shape of defect as `box-shadow:md`.

`mask-type` is the only member of the family that declares on the **mask**
element rather than on the masked one, which is why it and `mask-mode` are two
properties over the same two words.

`§ 12.6` prints twenty rows. Nine more leaves — `Position.{Top,Bottom,Left,
Right}`, `Repeat.{RepeatX,RepeatY,Round,Space}` and `Size.Auto` — complete the
three keyword ladders; each is confirmed against upstream v4's compiled output.

### Arbitrary values — `rawShadow`, `rawTextShadow`, `rawMaskImage`

Upstream's `shadow-[…]`, `text-shadow-[…]` and `mask-image-[…]` are
**top-level variants with a payload**, not leaves inside their section: a
payload leaf nested inside an enum section cannot be constructed by any
spelling (see *`Color.Hex("#abc")` is declared and unconstructible*). The name
keeps the path it would have had, flattened.

{mask-raw/src/main.bp}

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

### Nothing in `Effect`, `Blend` or `Mask` resolves a shadow

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

### Not declared

`shadow-<color>/<opacity>` — upstream's `shadow-red-500/50`. `§ 12.1` gives the
class and the prose "Cor da sombra com opacidade" and **no property/value
pair**. The mechanism is no longer missing: front 56's `Rule.declarations` can
express the two-step protocol, where the colour utility writes a custom
property and the shadow utility reads it back. The **value** still is, so there
is nothing byte-equal to emit, and it reopens the moment the reference carries
a row.

## Filter and BackdropFilter — `§ 13`

`Filter` is `§ 13.1` on `filter`; `BackdropFilter` is `§ 13.2` on
`backdrop-filter` (not `Backdrop`, which is the `::backdrop` modifier).

{filter/src/main.bp}

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

## Svg and A11y — `§ 18`, `§ 19`

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
