# Motion

> Package: [`rakun-stylesheet`](../docs.md) · index: [`../../docs.md`](../../docs.md)

## Transition and Animate — `§ 15`

Before front 44 there was no `transition` token anywhere in rakun-stylesheet, which meant
every state front 34 made expressible arrived in **one frame**: a button that
darkens on hover darkened between two frames with nothing in between. There was
also no `animate-spin`, so "something is happening" — the most common piece of
feedback an application gives — had no token at all and needed a hand-written
stylesheet beside rakun-stylesheet.

`Transition` is `§ 15.1`–`§ 15.5` and `Animate` is `§ 15.6`. **36 leaves.**

### The presets — one token, three declarations

`§ 15.1` is unusual: six of its seven rows are **three declarations from one
utility**. `transition-colors` sets the property list, the timing function and
the duration together. rakun-stylesheet needs no new machinery for that — `tokensToCss`
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

### `transition-behavior` — the class and the value disagree

| Token | CSS |
| --- | --- |
| `.Transition.Behavior.Normal` | `transition-behavior:normal` |
| `.Transition.Behavior.Discrete` | `transition-behavior:allow-discrete` |

`transition-discrete` emits `allow-discrete`, not `discrete`. It has a test of
its own, asserted in both directions, because it is exactly the row that gets
written from memory and gets written wrong.

### Duration, delay and easing

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

`ease-linear` is CSS's own keyword; upstream has no `--ease-linear` and rakun-stylesheet
does not invent one.

### A preset then an override

{transition-override/src/main.bp}

Two tokens, two rules, four declarations — and the preset's `150ms` is still in
the output with the `200ms` after it. **List order is declaration order**, so
the later one wins; reversing the two is a different class whose preset now
overrides the override.

### `transitionEntries()` — upstream's three `--ease-*` values

`defaultTheme()` carries the four `--animate-*` entries and **no `--ease-*`**,
so a project composes them:

{transition-entries/src/main.bp}

| Name | Value |
| --- | --- |
| `--ease-in` | `cubic-bezier(0.4, 0, 1, 1)` |
| `--ease-out` | `cubic-bezier(0, 0, 0.2, 1)` |
| `--ease-in-out` | `cubic-bezier(0.4, 0, 0.2, 1)` |

`§ 15.4` prints the three *names* and no value; the cubic-beziers are
upstream v4's `theme.css` (4.3.2), byte for byte. The namespace is front 54's
`Ns.Ease`, so `extendTheme` accepts them and `clearNamespace(th, Ns.Ease)` drops
exactly these three; every rule references the variable and never its value.

### Animate — a declaration and a block

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

### Arbitrary values — `rawTransitionProperty`, `rawAnimate`

{transition-raw/src/main.bp}

`Token.TransitionProperty(value)` and `Token.AnimateRaw(value)` are **top-level**
variants, not `Transition.Property(…)` / `Animate.Raw(…)`, because a payload
leaf nested inside an enum section cannot be constructed by any spelling (see
§ `Color.Hex("#abc")` is declared and unconstructible). For `AnimateRaw` that is
not an inconvenience: it is the *only* way to name an animation this library
does not ship, so the nested spelling would have shut the door rather than
narrowed it. The wrappers exist because a leading-dot path followed by a payload
call does not carry the typed-array context either.

`rawAnimate` goes through `declSheet` and **not** through `animateTokenToSheet`:
a custom animation names keyframes rakun-stylesheet does not own, so it hoists no block.

`§ 15` prints no arbitrary-value row; both were measured against upstream v4.
`rawAnimate` is `animation:<value>`, as upstream's `animate-[…]`.
`rawTransitionProperty` writes the property **and** the timing and duration
defaults, as upstream's `transition-[…]` and every preset beside it do:
`transition-property:width;transition-timing-function:var(--ease-out);transition-duration:150ms`.

### Nothing in `Transition` or `Animate` resolves a timing function

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

### Not declared

`@starting-style`. `§ 15` has six subsections and none of them mentions it, so a
token for it would be written from memory. Front 56's `Sheet.blocks` would carry
it the day the reference does.

## Transform — `§ 16`

Ninety-six leaves in one section over sixteen sub-sections: `Rotate` (with a
`Neg` sub-section), `Scale`, `ScaleX`, `ScaleY`, `TranslateX`, `TranslateY`,
`SkewX`, `SkewY`, `Origin`, `Style`, `Backface`, `Perspective`,
`PerspectiveOrigin`, `Zoom` and `Shorthand`. Front 44 shipped
`Transition.Transform`, which names `transition-property:transform` — a
transition over a property no other token could set — and this section is what
makes it mean something.

### In v4 `rotate`, `scale` and `translate` are properties, not functions

That is the change the whole section rests on. Three tokens in one list are
three declarations in one rule and none overwrites another:

{transform-lifted/src/main.bp}

Three properties, so none overwrites another; the pre-1.0.10
`transform:rotate(45deg) scale(1.1)` shape is gone. Scale and translate also
write their axes into `--tw-*` variables, as upstream v4 does, so two axes of
one family compose too.

### Rotate, and the negative half

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

### Scale — upstream v4's three variables

A step is a **percentage** written into `--tw-scale-x`, `--tw-scale-y` and
`--tw-scale-z`, then read by one `scale:var(--tw-scale-x) var(--tw-scale-y)`;
`ScaleX` / `ScaleY` write their own axis only, so the two compose:

{transform-scale/src/main.bp}

The three variables are registered with `@property` (initial value `1`), so an
axis nobody set reads as identity. The reference file's `scale:.5` /
`scale:.5 1` is v3's shape. `.Transform.Zoom.__50` stays `zoom:0.5`, the
reference's bare number.

### Translate — upstream v4's two variables

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

### Skew — upstream v4's variable and chain

`§ 16.6`'s "Propriedade CSS" column says `skew-x: 3deg`. That is not a
registered CSS property. Upstream writes the axis into a variable and a chain
of five variables into `transform`, and so does rakun-stylesheet:

{transform-skew/src/main.bp}

An unset variable is nothing (the empty fallback), so **two skews in one rule
compose**. Each skew class registers the chain's five variables with
`@property` (no initial value).

### Origin, style and backface

`.Transform.Origin.*` is the nine values of `§ 16.8`; a corner is two keywords
(`transform-origin:top right`, never `top-right`). `.Transform.Style.Flat` and
`.Transform.Style.Preserve3d` are `§ 16.9` — note that the Tailwind class is
`transform-3d` and the value is `preserve-3d`, which is why the leaf is named
after the value. `.Transform.Backface.{Visible,Hidden}` is `§ 16.1`.

### Perspective — a theme namespace

| token | CSS | theme entry |
|---|---|---|
| `.Transform.Perspective.None` | `perspective:none` | — (a CSS keyword) |
| `.Transform.Perspective.Dramatic` | `perspective:var(--perspective-dramatic)` | `100px` |
| `.Transform.Perspective.Near` | `perspective:var(--perspective-near)` | `300px` |
| `.Transform.Perspective.Normal` | `perspective:var(--perspective-normal)` | `500px` |
| `.Transform.Perspective.Midrange` | `perspective:var(--perspective-midrange)` | `800px` |
| `.Transform.Perspective.Distant` | `perspective:var(--perspective-distant)` | `1200px` |

`defaultTheme()` does not carry the namespace, so compose it:

{transform-perspective-theme/src/main.bp}

Like front 44's `--ease-*`, **none of these five values is provisional**:
`§ 16.2` prints the variable *and* its length on every row.
`.Transform.PerspectiveOrigin.{Center,Top,Bottom,Left,Right}` is `§ 16.3`.

### The `transform` shorthand — upstream v4's rows

`.Transform.Shorthand.None` is `transform:none`. `.Cpu` (`transform` /
`transform-cpu`) is the skew chain, and `.Gpu` puts `translateZ(0)` in front of
it:

```text
transform:translateZ(0) var(--tw-rotate-x,) var(--tw-rotate-y,) var(--tw-rotate-z,) var(--tw-skew-x,) var(--tw-skew-y,)
```

A `.Cpu` beside a `.SkewX.__3` therefore keeps the skew. `§ 16.7`'s
`translate(…) rotate(…) scaleX(…)` rows are v3's and are not emitted.

### Arbitrary values — `rawRotate`, `rawTranslate`

{transform-raw/src/main.bp}

`rotate-[17deg]` is in the reference (`§ 16.4`'s HTML example); the translate
hatch is **provisional** — `§ 16` prints no arbitrary translate row — and exists
because a translate the five steps do not name has no other spelling. It writes
both axes and reads neither variable.

Both are top-level `Token` variants for the reason every escape hatch in rakun-stylesheet
is: a payload leaf nested inside a section cannot be constructed. The wrappers
exist because a leading-dot path followed by a payload call does not carry the
typed-array context, so `[.TransformRotateRaw("17deg")]` does not parse.

### Nothing in `Transform` resolves a length

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

### Not declared

`rotate-x-*`, `rotate-y-*`, `rotate-z-*`, `translate-z-*`, `scale-z-*` and an
unaxed `translate-*`. `§ 16` has eleven subsections and none of them enumerates
a 3-D axis variant or a both-axes translate, so tokens for them would be written
from memory. The rest of the 3-D surface — `transform-style`, `backface-*` and
the perspective family — **is** in the reference and is shipped.

## Interact — `§ 17`

Cursor, form controls, pointer events, resize, selection, `will-change`,
touch, scrolling and snapping — one section, 161 leaves.

{interact/src/main.bp}

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
