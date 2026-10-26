# rakun-stylesheet — agent notes (was `emilia`)

> Package `rakun-stylesheet` (was `emilia`; front 165 s2) of the rakun workspace — the former `emilia-test` is `src/testing/` and `jhonstart-emilia` is `src/bridge/`, — `repository/rakun/modules/rakun-stylesheet/` · workspace rules: [`../../AGENTS.md`](../../AGENTS.md) · cells: `../../conformance/rakun-stylesheet/`

> Type-safe CSS-in-bp library for the rakun-bpp package. **Zero compiler
> surface** at v0 — the core is unaware of emilia (memory:
> `feedback_no_lib_specific_in_core`,
> `feedback_compiler_unaware_of_jhonstart`). Sibling of `rakun-bpp/html`
> and `query/query`: a typed sub-language consumed at the call site, but
> the sub-language is an **array literal of typed enum variants**, not a
> string.

## Surface (v0)

Three named imports from `from "rakun-stylesheet"`:

1. **`emilia(tokens: Token[]) -> string`** — the entry point. Walks
   the token list at runtime (v0 — no comptime expansion yet), maps
   each variant to a `Sheet`, names the class `e_` + std's `contentHash`
   of the sheet's rules as the document writes them (`output.bp`
   `classRules`, the class written `\u{1}` — `styled`'s class rule,
   decision 367), registers the `(name, encoded sheet)` pair on the
   per-render `Stylesheet`, returns the class name. Front 56 added
   **`emiliaWith(tokens, th)`**, the same under an explicit theme;
   `emilia(tokens)` is `emiliaWith(tokens, defaultTheme())`.
2. **`flush() -> string`** — drains the `Stylesheet` and renders the
   `<style>...</style>` **document** — the `@layer` statement, the theme
   layer, the base layer, the components layer, the utilities layer and
   the `@keyframes` blocks — AND clears the cell. Per-render contract —
   two consecutive calls emit two independent documents; the second has
   no `@layer utilities` body if no `register` happened in between.
   Front 56 added **`flushWith(o: Options)`**; `flush()` is
   `flushWith(defaultOptions())`.
3. **`Token` enum** — the typed authored surface (see `tokens.bp`).
   Sections: Text, Font, List, Color, Bg, Pad, Margin, Size, Space, Layout, Flex,
   Grid, Gap, Border, Outline, Ring, Divide,
   Effect, Blend, Mask, Filter, BackdropFilter, Transition, Animate, Transform, Gradient + the 83 modifier variants of front 34, each carrying a nested
   `Token[]` (see below and `conformance/rakun-stylesheet/modifiers/docs.md`). Front 41 rebuilt **`Effect`**
   (Shadow, InsetShadow, TextShadow, Opacity) and added **`Blend`** and
   **`Mask`**, plus three top-level arbitrary-value variants
   `EffectShadowRaw(value)` / `EffectTextShadowRaw(value)` /
   `MaskImageRaw(value)` with the wrappers `rawShadow` / `rawTextShadow` /
   `rawMaskImage`. Front 33 widened **`Color`** to the
   26-family x 11-shade grid (17 chromatic Red..Rose + 9 neutral
   Slate..Taupe, each `50 100 … 900 950`) plus
   `White`/`Black`/`Transparent`/`Current`/`Inherit` and the `Hex(string)`
   escape, and added **`Bg.Color`** — the same grid on `background-color`,
   plus the five named colours. `Bg`'s legacy Red/Blue/Gray/White/Black/Hex
   leaves keep the `background` shorthand and their pre-33 output beside it.
   The top-level **`Alpha(percent: i32, inner: Token[])`** wrapper is front
   33's too — upstream's `/N` opacity suffix, rewriting each inner
   declaration's value into `color-mix(in oklab, <value> N%, transparent)`.

Front 54 adds the **theme** and the **spacing ladder** (`theme.bp`,
`spacing.bp`): `ThemeEntry`, `Theme`, `DarkMode`, `Ns`, `nsPrefix`,
`allNamespaces`, `defaultTheme`, `emptyTheme`, `extendTheme`, `clearNamespace`,
`namespace`, `themeValue`, `themeVar`, `themeCss`, `keyframeCss`, `darkAtRule`,
`darkSelector`, `withDarkMode`, `spacing`, `spacingHalf`, `spacingNegHalf` — see `conformance/rakun-stylesheet/theme/docs.md`. Rewiring `tokenToCss` to `spacing()` and to the theme is fronts
33–47's work. Front 35 took **six** of the seven drifted `rem` ladders front 54
found in `emilia.bp` — `padScaleX/Y/All` and `marginScaleX/Y/All`; the seventh,
`flexGapScale`, was `Flex.Gap`'s and belonged to front 37, which owns that
section. **Front 37 deleted it**, so all seven are gone and no literal `rem`
ladder is left in `emilia.bp`; `spacing.bp`'s docblock, which still claimed all
seven for front 35, was corrected in the same commit.

Front 56 adds the **rule model, the codec and the renderer** (`output.bp`) —
see `conformance/rakun-stylesheet/output/docs.md` § The cascade and the output. It is the interface fronts 33, 34
and 35 consume, so it is stated here in one line each:

| Name | What 33/34/35 see |
| --- | --- |
| `Rule(layer, atRules, selector, declarations, important)` | one style rule; `atRules` outermost-first, `declarations` `;`-joined with no braces |
| `Block(header, body)` | a rule that is not a style rule — `@keyframes spin` + its brace-balanced body |
| `Sheet(rules, blocks)` | what a token list produces, and what a `…TokenToSheet` arm returns |
| `Variant(atRule, selector)` | what a modifier is — **front 34 writes one `Variant`-returning fn per variant name and nothing else about emission** |
| `selector` | a nesting template with **exactly one `&`**; no `&` means a literal selector; two or more is refused, with no argument that permits it |
| `emptySheet()` / `declSheet(decls)` | the one-line adapter for a section dispatcher; `declSheet("")` is `emptySheet()` |
| `staticSheet(layer, selector, decls)` | a rule whose selector is literal — 54's `:root`, 55's reset |
| `blockSheet(header, body)` | a `@keyframes` sheet — front 44's `animate-*` |
| `mergeSheet(a, b)` / `declarationsOf(s)` / `layerNames()` | concatenate rules then blocks; read every declaration back; the cascade order, written once |
| `nestVariant(s, v)` / `markImportant(s)` | wrap a sheet in a variant; set `important` on every rule — front 34's `Important(inner)` is one line on top |
| `encodeSheet(s)` / `decodeSheet(raw)` / `carriesSeparator(s)` | the codec that carries a `Sheet` through a string-keyed host cell, and the check its assumption rests on |
| `Options(theme, base, prefix, important, layers)` + `defaultOptions()` + the five `with…` | the build-level knobs; `withBase` is how front 55 turns preflight on |
| `renderRule(className, r, o)` / `renderDocument(raw, o)` | one rule; the whole `<style>` document |
| `classRules(s)` | the class's rules as the document writes them (layer order, plain before conditioned, runs folded), the class written `\u{1}` — what the class name hashes (decision 367, `contracts.md` § 4); no option enters it |
| `styleRule(tokens, th)` (in `emilia.bp`) | the pure half of `emiliaWith`: `#("e_" + contentHash(classRules(sheet)), encodedSheet)`, no host cell touched — rakun-ssr front 68's build-time `styleMap` |
| `fullTheme()` / `fullOptions()` (in `emilia.bp`) | decision 80: `defaultTheme()` extended by every contributing front's entries, one line per front; `flush()` renders with `fullOptions()`. `defaultOptions()` cannot carry it — `output.bp` cannot import `emilia.bp` |

**Fronts 33–47 never see `Rule`, `Sheet` or `Variant`.** A section dispatcher
keeps returning a declaration string and the shared `case` in `emilia.bp`
adapts it — `Text(_inner) -> declSheet(textTokenToCss(_inner))`. A front whose
tokens genuinely need a selector (`space-x-*`, `divide-*`) writes a
`…TokenToSheet(t, th) -> Sheet` instead and says so in its own README. Two
shapes, one line each in the shared `case`.

**The `Theme` reaches the shared dispatcher, not the sub-dispatchers.**
`tokenToSheet(t, th)` carries it and every modifier arm already uses it
(`Md(inner) -> nestVariant(tokensToSheet(inner, th), mdVariant(th))`). The ten
section sub-dispatchers still have their front-54 signature
(`fn textTokenToCss(t: Token.Text) -> string`): front 56 owns the shared
dispatcher and the public entry points, **not** the per-section ones, so a
front that needs the theme adds the parameter to its own function and to its
own one line of the shared `case` — still one line each, and no front-56 commit
touching a file two other fronts are editing.

Front 34 owns the **modifier table** — the variants under the
`// ── front 34 — modifiers ──` banner in `tokens.bp`, the block of the same name
in `emilia.bp` (one `Variant`-returning fn per name, plus its arms of the shared
`case`), and nothing about emission. There are **83** of them, 82 variants and
the one flag: five breakpoints and their five `max-` mirrors (all ten read the
theme's `--breakpoint-*`, so an override moves the query AND the class hash),
`Dark` and eight other media features, nine interaction states, sixteen form
states, nine structural positions plus the indexed `Nth`/`NthLast`, nine
pseudo-elements, six `Group*` and eight `Peer*` (plus `GroupNamed(name, inner)` /
`PeerNamed(name, inner)`, decision 401: they name the group / peer of the state
tokens in `inner`, `.group\/name`), `Rtl`/`Ltr`/`Children`/
`Descendants`, and `Important` (decision 81), which is `markImportant` rather
than a `Variant`. `Dark` consumes front 54's `darkAtRule`/`darkSelector` and
never learns which `DarkMode` strategy is in force: `Media` puts the whole
strategy in the at-rule, `Class` and `Attribute` in the selector, and a cell
proves each. A RANGE is nesting, not a name — `md:max-xl:` is
`Token.Md([Token.MaxXl([…])])`.

Front 36 owns the **layout section** — `Layout` in `tokens.bp` and
`layoutTokenToCss` with its sub-dispatchers in `emilia.bp`, fenced by the
`// ── front 36 — layout ──` banner in both files. The eleven display values are
the section's OWN leaves, so `.Layout.Flex` keeps its pre-36 spelling; everything
else in `§ 5` is a sub-section beside them (`Position`, `Inset`, `Overflow`,
`Overscroll`, `Visibility`, `Z`, `Isolation`, `Float`, `Clear`, `Object`,
`Aspect`, `Columns`, `Break`, `Box`, `BoxDecoration`) — 785 leaves. Its rule is
front 35's rule: **no leaf resolves a length**. `Inset` answers front 54's
`spacing(n)` / `spacingHalf(n)`, the same two functions `Pad` and `Margin`
answer, so `.Layout.Inset.T.4` and `.Pad.T.4` agree by construction; the named
column widths answer front 35's `containerVar`, so `.Layout.Columns.Md` and
`.Size.MaxW.Md` are the same reference. `Z` is the one numeric family that is
not a length — a bare integer. `layoutTokenToCss(t, th)` and every
sub-dispatcher under the banner take `th: Theme`. **`Flex`/`Grid` the container
properties are front 37's**, and `Gap` with them; `display:flex` is here only
because it is a display value.

Front 37 owns **flexbox, grid and gap** — the `Flex`, `Grid` and top-level `Gap`
sections of `tokens.bp` and `flexTokenToCss`, `gridTokenToCss` and
`gapTokenToCss` with their sub-dispatchers in `emilia.bp`, fenced by the
`// ── front 37 — flexbox, grid and gap ──` banner in both files. **356 leaves**
over the whole of `§ 6`. Its rule is fronts 35's and 36's: **no leaf resolves a
length**. Only two families here ARE lengths — `Flex.Basis` and the whole of
`Gap` — and both answer front 54's `spacing(n)` / `spacingHalf(n)` over front
35's scale, so `.Flex.Basis.4`, `.Gap.All.4` and `.Pad.All.4` agree by
construction; `Grow`, `Shrink`, `Order` and every `Grid` count, span and line
number are bare integers and reach `spacing` never. `gridRepeat(n)` builds
`repeat(N, minmax(0, 1fr))` and `gridFr()` the `minmax(0, 1fr)` inside it —
each spelled once, and the implicit `fr` tracks read the second. **The whole
alignment family stays under `Flex` although it applies to grid too**: moving
`Items` and `Justify` would rename tokens that compile today, and a grid
container writing `.Flex.Justify.Center` gets the correct CSS — only the
spelling reads as flex-only. `align-self` is `Flex.AlignSelf` and `place-*` is
the flat `Flex.PlaceContent`/`PlaceItems`/`PlaceSelf`, because **`Self` is a
language keyword** (§ Maintainer rules). The pre-37 `.Flex.Gap.{1,2,4,8}` paths
keep compiling and now emit what `.Gap.All.N` emits.

Front 35 owns the **spacing and sizing sections** — `Pad`, `Margin`, `Size` and
`Space` in `tokens.bp`, and `padTokenToCss`, `marginTokenToCss`,
`sizeTokenToCss` and `spaceTokenToSheet` in `emilia.bp`, fenced by the
`// ── front 35 — spacing and sizing ──` banner in both files. Its one rule:
**no leaf resolves a length**. Every value answers front 54's `spacing(n)` /
`spacingHalf(n)`, so `calc(var(--spacing) * N)` is spelled once in the library
and the whole scale consumes it. `Pad`/`Margin`/`Size` are ordinary
`…TokenToCss` dispatchers adapted by `declSheet`; `Space` is the one dispatcher
here that answers a `Sheet`, because `space-y-*` declares on the element's
CHILDREN and so needs a selector outside the class. That selector is
**`pub fn siblingSelector()`** — `:where(& > :not(:last-child))`, upstream's zero-specificity form since the audit pass — and **front 40 must
call it rather than re-spell it**: `divide-*` separates the same children the
same way, and two fronts writing the same selector by hand are two fronts that
will eventually write it differently.

Front 40 owns **borders, outlines, rings and divided lists** — the `Border`,
`Outline`, `Ring` and `Divide` sections of `tokens.bp` and `borderTokenToCss`,
`outlineTokenToCss`, `ringTokenToSheet` and `divideTokenToSheet` with their
sub-dispatchers in `emilia.bp`, fenced by the
`// ── front 40 — borders, outlines, rings and divides ──` banner in both files.
**1704 leaves** over the whole of `§ 11`. Its rule is fronts 35's, 36's and
37's, one level up: **no leaf resolves a COLOUR or a RADIUS**. All five colour
sub-sections — `Border.Color`, `Outline.Color`, `Ring.Color`,
`Ring.Offset.Color` and `Divide.Color` — answer front 33's `paletteVar`, and
this front holds no colour table; every radius answers `radiusVar`, which is
front 54's `--radius-*` ladder and the only place the front spells one.

**Two of the four are `…ToSheet` dispatchers**, front 56's second shape, and
they are the only two this front adds. `divideTokenToSheet` needs a selector
outside the class because `divide-*` declares on the element's CHILDREN, and it
CALLS front 35's `siblingSelector()` rather than re-spelling
`:where(& > :not(:last-child))` — the test front 35 could not write, comparing the two
families' selectors byte for byte, is now in `emilia.bp`.
`ringTokenToSheet` needs several ordered declarations because a ring is a
box-shadow. **Since the audit pass, every ring and shadow token writes ONE
CHANNEL and the same reader** — `boxShadowChain()`, upstream v4's five
channels (`--tw-inset-shadow`, `--tw-inset-ring-shadow`,
`--tw-ring-offset-shadow`, `--tw-ring-shadow`, `--tw-shadow`), each with the null
shadow `0 0 transparent` as its fallback (emilia registers `@property` only for
the transform variables, front 45).
The pre-fix ring listed three channels with NO fallback, so a lone `Ring.W.2`
was invalid at computed-value time and drew nothing, and `Effect.Shadow` wrote
`box-shadow` itself, so a ring and a shadow in one class did not compose.
Front 41's shadows now write `--tw-shadow` (`InsetShadow` writes
`--tw-inset-shadow`), the ring width is upstream's `ringShadowValue` (inset flag,
width grown by the offset, `currentcolor` default) and `Ring.Offset.W` writes
the offset shadow beside its width.

**What front 40 changed under other fronts.** `.Border.Color.<family>.<shade>`
used to emit `border-color:red` — the shade was discarded — and now emits the
palette reference; `examples/emilia-modifiers` pinned the old text and was
updated. `.Border.Rounded.{Sm,Md,Lg}` used to resolve a literal `rem` and now
reference `var(--radius-*)`; `Full` and `None` still do not, because upstream
prints those two literally. That last change cost three other fronts their walk
CONTROL: fronts 36, 37 and 39 all asserted `.Border.Rounded.Lg` DOES carry a
`rem`, to prove their probes discriminated. All three now point at
`.Text.Size.Lg`, which then still spelled `1.125rem` — until front 38, whose
  own job was to make it `var(--text-lg)`, took that away too. **A front
that makes a literal into a reference must grep for its own tokens in other
fronts' controls** — the README said no existing assertion covered `Sm`, `Md`
or `Lg`, and three did.

**`space-*` and `divide-*` are upstream's reverse-aware pair** (verified against
`utilities.ts` on 2026-09-26, decisions-pending 05emilia-g): `reversePair(flag,
start, end, v)` resets the axis flag to `0` and writes the START side times the
flag and the END side times one minus it, so `Space.XReverse` /
`Divide.XReverse` move the gap instead of setting a variable nothing read — which
is what the pre-audit end-only form did.

**One convention is deliberately not uniform.** `.Border.W.0` emits
`border-width:0` and not `0px`, because the front's acceptance says the four
pre-40 leaves emit exactly what they emitted before; the eight directional
sub-sections follow the shorthand so that one section speaks one way.
`Outline.W.0` and `Divide.{X,Y}.0` emit `0px`, the first from the README and
the second VERIFIED against upstream.

Front 38 owns **typography** — the `Text`, `Font` and `List` sections of
`tokens.bp` and `textTokenToCss`, `fontTokenToCss` and `listTokenToCss` with
their sub-dispatchers and `typographyEntries()` in `emilia.bp`, fenced by the
`// ── front 38 — typography ──` banner in both files. **437 leaves** over the
whole of `§ 9`. Its rule is fronts 35's, 36's, 37's and 40's, one level up:
**no leaf resolves a FONT SIZE, a LEADING, a TRACKING, a COLOUR or an INDENT.**
`Size` answers front 54's `--text-*` namespace as a PAIR — font-size AND its
`--text-*--line-height`, which emilia used to drop entirely — `Tracking` and
`Leading` answer `--tracking-*` / `--leading-*`, `Decoration.Color` answers
front 33's `paletteVar` (this front holds no colour table), and `Indent`
answers front 54's `spacing(n)`, the same function `.Pad.All.8` answers.

**What front 38 changed under other fronts.** Four compiling paths changed what
they EMIT, each because what they emitted was not `§ 9`'s form: `.Text.Size.*`
was a literal `rem` with no leading and is now the `var(--text-*)` pair;
`.Font.{Sans,Serif,Mono}` spelled a family stack and now reference
`var(--font-*)` (the stacks moved into `typographyEntries()`);
`.Text.Underline` and `.Text.LineThrough` were the `text-decoration` SHORTHAND
and are now `text-decoration-line`, which is what lets a line compose with
`Decoration.Style` instead of being overwritten by it. **`.Text.Bold` is not
one of them** and its six assertions are untouched. The size change **deleted
the library's last resolved `rem`**, which was the walk CONTROL of fronts 36,
37, 39 and 40 — see § Maintainer rules.

`typographyEntries() -> ThemeEntry[]` is this front's half of the theme, composed
the way front 33's `paletteEntries()` is
(`extendTheme(defaultTheme(), typographyEntries())`): nine `--font-weight-*`,
six `--tracking-*`, five `--leading-*` and the three family stacks. It does
**not** restate `--text-*` — front 54's `defaultTheme()` already carries all
thirteen sizes and all thirteen line-heights with `§ 21.3`'s values, and a
second transcription of one table is how two tables drift. **The three
`--font-*` family rows are upstream's**: the reference prints the reference
FORM and no value for it, so the stacks are copied from upstream v4's
`theme.css` (4.3.2). `text-indent`'s `calc(var(--spacing) * N)` shape is
confirmed against upstream's compiled `indent-8` (`§ 9.25` shows only HTML).

Front 42 owns **filters** — the `Filter` and `BackdropFilter` sections of
`tokens.bp` and the two top-level variants `FilterRaw` / `BackdropRaw`, and
`filterTokenToCss`, `backdropFilterTokenToCss` with their sub-dispatchers,
`filterChain()` / `backdropFilterChain()`, `filterEntries()` and the wrappers
`rawFilter` / `rawBackdropFilter` in `emilia.bp`, fenced by the
`// ── front 42 — filters ──` banner in both files. **108 leaves** over `§ 13`.
**The section is `BackdropFilter`, not the spec's `Backdrop`**: `Backdrop(inner)`
is front 34's `::backdrop` modifier, and a section head named like a top-level
payload variant is the collision below. **Every leaf but `Blur.None` is TWO
declarations** — its family's `--tw-<family>` custom property and one reader
that lists all nine families, each `var(--tw-<family>, )` with an EMPTY
fallback (front 39's `cssVarOr`, called) — so two filter tokens compose. The
spec's `filter:var(--tw-filter)` reader with `--tw-filter` a theme entry is
**not expressible and would not work**: `extendTheme` refuses `--tw-`, and a
`:root` definition resolves its `var()`s on `:root`, where no family is set.
The reader is spelled once, in `filterChain()`. `DropShadow.None` follows
upstream (`--tw-drop-shadow: ` plus the reader) because the reference's
`drop-shadow(none)` is not valid CSS; `Blur.None` keeps the reference's
`filter:none`. `filterEntries()` carries the seven `--blur-*` and six
`--drop-shadow-*` values from upstream's `theme.css`; `defaultTheme()` carries
neither namespace.

Front 43 owns **tables** — the `Table` section of `tokens.bp` and the top-level
`TableSpacingRaw`, and `tableTokenToCss` with its sub-dispatchers and the wrapper
`rawTableSpacing` in `emilia.bp`, fenced by the `// ── front 43 — tables ──`
banner in both files. **21 leaves** over `§ 14`. No leaf resolves a length:
`border-spacing` answers front 54's `spacing(n)`, whose `spacing(0)` is already
the bare `0` `§ 14.2` prints. `SpacingX`/`SpacingY` are the two-value forms of
the one property, as the spec designs them, so an X and a Y token in one list do
NOT compose (upstream composes them through `--tw-border-spacing-*`).

Front 55 owns **preflight** — `preflight.bp` (`pub mod preflight;` in
`root.bp`, `files` in `botopink.json`): `preflightRules()`, eleven `base`-layer
rules with literal selectors covering the eight bullets of `§ 4`, and
`preflight()`, the same rules as a plain CSS fragment for a static `reset.css`.
It claims PARITY WITH `§ 4`, not byte-equality with upstream `preflight.css`.
Rule 1 adds `border-style:solid` beside `border-width:0` — a DECISION, because a
zero width over the browser's `border-style: none` leaves every `Border.W.*`
inert. **The reset is opt-in and an argument only**: `defaultOptions()` carries
`base: []`; `withBase(o, preflightRules())` turns it on.

Front 57 owns **the escape hatches** — `arbitrary.bp` and the six TOP-LEVEL
variants `Arb(prop, value)`, `ArbProp(name, value)`, `ArbVariant(selector,
inner)`, `ArbAt(query, inner)`, `ArbMin(px, inner)`, `ArbMax(px, inner)` under
the `// ── front 57 — escape hatches ──` banner at the end of `Token`, with six
arms in `tokenToSheet`. **This is emilia's security surface: refuse, never
sanitise, no opt-out.** A payload that could close a rule (`}`) or the `<style>`
element (`<`) is refused twice — at COMPTIME by the template validators
(`cssValue`/`cssIdent`/`cssSelector`/`cssQuery`/`cssLength`, which fail the
build with the text) and at RUN TIME by the builders and again by the dispatcher
helpers (`panic`), because a bare `Token.Arb(…)` constructor cannot be made
private. `arbitrary.bp` cannot import `emilia.bp` (which imports it), so the
`Token[]`-carrying helpers take the inner list already folded to a `Sheet`, and
the rendering tests live in `emilia.bp` under the front's banner.

Front 58 owns **container queries** — `container.bp`, the payload-free
`Container { Inline, Normal, Size }` section and the TOP-LEVEL
`ContainerNamed(name)`, `ContainerAt(size, inner)`, `ContainerAtNamed(size, name,
inner)` under the `// ── front 58 — container queries ──` banner, four arms in
`tokenToSheet`. The size is a theme KEY written only by `containerKey`; the
query reads `--container-<key>` through `themeValue` (a container query cannot
hold a `var()`), so narrowing `--container-md` moves only the `md` queries, and a
size the theme does not define — or a key outside the thirteen — PANICS rather
than emitting `@container (width >= )`. `ContainerNamed` is both halves of
`@container/main` (type and name); every container name goes through front 57's
`cssIdent` reject set.

Front 59 owns **custom utilities and variants** — `compose.bp`, and nothing
in `tokens.bp` or the dispatcher. A bundle is a `pub fn … -> Token[]`
(`scrollbarHidden`, `§ 20.4`), `@apply` is `append` / `compose([…])`, a custom
variant is a function over the inner list (`hocus`, the general
`selector(Variant, inner)` through front 57's `arbSel`/`arbAt` checks, and
`themeMidnight`) — the parameter is `@slot`. **`named(className, tokens)` is the
one registration that does not hash**: it lands in `@layer components` (so a
utility on the same element wins by layer order), refuses the `e_` prefix and
anything `cssIdent` refuses, and refuses a SECOND, DIFFERENT registration under
one name. **`named()` lives in `emilia.bp`**, beside `register` and the
read-only `lookupRule` cell it needs, because `compose.bp` cannot import
`emilia.bp` (see the sibling-import rule below) and a host cell does not cross
modules; front 59's rendering tests live there too. The test helper
`panicMessage` is `arbitrary.bp`'s — on erlang it unwraps `{panic, Msg}` so a
panic message compares byte for byte on both targets.

Front 48 owns **the class slot** — `attributes.bp` (the contract in its header,
`mergeClass`, `nonAsciiIn`) and, under the front 48 banner in `emilia.bp`,
`className`, `styled`, `styledWith`, `cls`, `clsWith` and `assertAsciiBody`: they
hash a sheet, and a sibling cannot import `emilia.bp`, so the spec's
`html_hook.bp` is not a file — its two functions are `cls`/`clsWith` there. The
class is `emiliaWith(tokens, th)` refused first when its body is not ASCII
(the JS and erlang hashes diverge above U+FFFF). The shared fixture
`class: attributes — the shared fixture` asserts `e_f51c2501` for `cardTokens()`
under `defaultTheme()` on both rows; the rakun-stylesheet bridge (rakun-bpp front
30) and rakun-ssr front 68 must assert the same literal. rakun-bpp's half is
`modules/rakun-bpp/src/html_attrs.bp` (`classAttr`, `withAttrs`, `attrValue`),
which names no styling library. **A `[class]={…}` hole may not contain a space**
(rakun-bpp `html.bp` splits a tag body on `" "`): bind `cls(tokens, th)` to a
`val` first.

Front 44 owns **transitions and animation** — the `Transition` and `Animate`
sections of `tokens.bp` and the two top-level variants `TransitionProperty` /
`AnimateRaw`, and `transitionTokenToCss`, `animateTokenToSheet`,
`transitionEntries()` and the wrappers `rawTransitionProperty` / `rawAnimate` in
`emilia.bp`, fenced by the `// ── front 44 — transitions and animation ──`
banner in both files. **36 leaves** over the whole of `§ 15`. Its rule is fronts
35-41's, one family further on: **no leaf resolves a TIMING FUNCTION or an
ANIMATION.** `Ease` answers front 54's `Ns.Ease` and `Animate` its `Ns.Animate`,
so the three cubic-beziers and the four animation shorthands are theme entries.
The two ms ladders are the exception and it is the REFERENCE's: `§ 15.3` and
`§ 15.5` print `transition-duration: 150ms` literally and upstream has no
`--duration-*` namespace, so `150ms` inside the six presets is the same literal
from the same rows.

**`animateTokenToSheet` is the one `…TokenToSheet` dispatcher in fronts 41-47**,
front 56's second shape, and it is the only one this front adds. `animate-spin`
is half a rule: the other half is the `@keyframes spin` BLOCK, which is not a
style rule and cannot be nested in one. `blockSheet` carries it, `renderDocument`
hoists it outside every cascade layer, and `dedupeBlocks` is what makes two
spinners on a page one block. The `Animate` arm of `tokenToSheet` is therefore
the one arm of this front that does not go through `declSheet`, and
`AnimateRaw`'s arm DOES — a custom animation names keyframes this front does not
own, so it hoists none.

**THE KEYFRAMES GATE THE SPEC OPENS WAS ALREADY CLOSED BY FRONT 54.** The front
README asks this front to read the upstream page, paste the four `@keyframes`
bodies into the dispatcher, record the date and tick a `TODO.md` checkbox —
because `§ 15.6` and `§ 21.6` print the shorthand and never a keyframes body.
`theme.bp` already carries them: `animateEntries()` has the four `--animate-*`
entries and `keyframeEntries()` the four bodies, both inside `defaultTheme()`,
and `output.bp`'s `themeBlocks` already hoists them. So `animationSheet(th,
name)` READS THE BODY OUT OF THE THEME through `keyframeCss(th)` rather than
pasting a second copy beside it — front 38 declined the same invitation over
`--text-*`, for the same reason. The consequence is asserted rather than left as
prose: under a theme carrying no body for a name, the token emits its
declaration and hoists NO block, which is also what makes `.Animate.None` and
`AnimateRaw` blockless without a special case. **A front that finds a spec gate
already closed by a landed front closes it by citation, not by a second
transcription** — and says so where a reader will hit it.

`transitionEntries() -> ThemeEntry[]` is this front's half of the theme, composed
the way front 33's `paletteEntries()` and front 38's `typographyEntries()` are:
three `--ease-*` entries, which `defaultTheme()` does NOT carry although it does
carry the four `--animate-*`. `§ 15.4` prints the three NAMES and no value;
**the three VALUES are upstream's** `theme.css` (4.3.2), byte for byte. The
NAMESPACE is front 54's `Ns.Ease`, and every rule names the variable, never its
value. The two arbitrary-value variants were measured against upstream:
`AnimateRaw` is `animation:<value>`, and `TransitionProperty` writes the
property plus the timing and duration defaults through `transitionPreset`, as
upstream's `transition-[…]` and the presets beside it do.

**WHAT FRONT 45 INHERITED, AND WHAT IT MEASURED.** Front 45 (transforms) took
all four of the things this front left it. The head audit ran: a `Transform`
SECTION beside the LEAF `Transition.Transform` resolves and dispatches on both
targets — a head beside a leaf, as front 41's head-beside-a-head was — and no
top-level `Transform(…)` PAYLOAD variant was declared. `Transition.Transform`
already emitted `transition-property:transform`, so the `Transform` tokens were
animatable the day they existed with no edit here, and both worked examples pair
the two. `transitionEntries()` was the pattern for `transformEntries()`, and
`animateTokenToSheet` was not needed — no transform token wants a block.

Front 45 owns **transforms** — the `Transform` section of `tokens.bp` and the
two top-level variants `TransformRotateRaw` / `TransformTranslateRaw`, and
`transformTokenToCss` with its sixteen sub-dispatchers, `transformEntries()` and
the wrappers `rawRotate` / `rawTranslate` in `emilia.bp`, fenced by the
`// ── front 45 — transforms ──` banner in both files. **101 leaves** (96, plus the
both-axes `Translate` the audit pass added) over the
whole of `§ 16`. Its rule is fronts 35-41's: **no leaf resolves a LENGTH.**
`translate-x-1` is front 54's `spacing(1)` and the five perspective keywords are
`--perspective-*` references, so the `100px` … `1200px` the reference prints in
parentheses are THEME ENTRIES. The two exceptions are `TranslateX.Px` and
`TranslateY.Px`, whose `1px` is the reference's own literal value; they are held
out of the length walk and asserted from the other side.

**THE FRONT RESTS ON A v4 CHANGE.** `rotate`, `scale` and `translate` are
INDEPENDENT CSS PROPERTIES in v4 and not `transform` functions, so three of them
in one token list are three declarations in one rule and none overwrites
another. That is why this front needs no `--tw-*` cascade to compose and why the
1.0.8 draft's `transform:rotate(45deg) scale(1.1)` shape is superseded
wholesale. `skew` is the exception, and it is upstream's: both axes write
`transform`, so two skews in one rule are two declarations of one property.

**THREE ROWS OF `§ 16` DID NOT SURVIVE; each takes upstream Tailwind v4's output
(4.3.2, compiled) and is flagged at the arm that emits it.**

- **`§ 16.6`'s property column is WRONG.** The reference file writes
  `skew-x: 1deg`, which is not a CSS property. Upstream writes the axis into
  `--tw-skew-<axis>` (`skewX(3deg)`) and then the five-variable chain
  `transform:var(--tw-rotate-x,) var(--tw-rotate-y,) var(--tw-rotate-z,)
  var(--tw-skew-x,) var(--tw-skew-y,)`, so the two axes compose; the twelve
  leaves emit exactly that and the reference file's spelling is asserted ABSENT.
- **`§ 16.10`'s one-axis rows compose through two variables.** Upstream writes
  the utility's axis into `--tw-translate-<axis>` and then
  `translate:var(--tw-translate-x) var(--tw-translate-y)`; both-axes
  `Translate` writes both variables. The identity default `0` is NOT a theme
  entry (`extendTheme` panics on `--tw-`, in none of `Ns`'s nineteen prefixes):
  it is upstream's `@property` registration, which each translate sheet carries
  as `Block`s (`twProperty`, `translateProperties()`; the skew sheets carry the
  chain's five with no initial value, `chainProperties()`), deduplicated by
  header at flush. `output.bp`'s `renderDocument` then writes upstream's
  fallback for an engine without `@property`: `@layer properties;` declared
  before every other layer and `@layer properties{@supports (…){*,::before,
  ::after,::backdrop{--tw-translate-x:0;…;--tw-skew-x:initial}}}` after the
  blocks (`propertiesFallback`; unlayered when `layers == false`, where the `*`
  selector loses to every class on specificity). `[.TranslateX.Half,
  .TranslateY.Half]` moves diagonally.
- **`§ 16.7`'s `transform-cpu` / `transform-gpu` rows are v3's.** Upstream v4's
  are the chain above (`Cpu`) and `translateZ(0)` + the chain (`Gpu`), with no
  `@property`; a `Cpu` beside a `SkewX` keeps the skew.

- **`§ 16.5`'s scale rows are v3's too.** Upstream v4 writes a PERCENTAGE into
  `--tw-scale-x/y/z` (`scale-50` all three, `scale-x-50` its own axis) and then
  `scale:var(--tw-scale-x) var(--tw-scale-y)`, registering the three with
  `@property` and the initial value `1` (`scaleProperties()`); the leaves emit
  exactly that, so `[.ScaleX.50, .ScaleY.150]` composes, and the reference
  file's `scale:.5` / `scale:.5 1` is asserted ABSENT. With each axis writing
  its own variable, `scale-x-100` and `scale-y-100` no longer collide: the
  distinctness walk asserts 101 distinct declarations.
- **A negative rotation multiplies**, as every negative v4 utility does:
  `-rotate-12` is `rotate:calc(12deg * -1)`.
- **A fraction is `calc(N / D * 100%)`** (`fraction(n, d)`, front 35's), never a
  rounded percentage: `translate-x-1/2` is `--tw-translate-x:calc(1 / 2 * 100%)`,
  the same string `w-1/2` and `top-1/2` carry.

**`transformEntries()` is this front's half of the theme** and — unlike front
44's three `--ease-*` — **none of its five values is provisional**: `§ 16.2`
prints the variable AND its length in parentheses on every row. What
`defaultTheme()` does not carry is the namespace at all, so a project composes
`extendTheme(defaultTheme(), transformEntries())`. `perspective-none` is
deliberately absent: it is a CSS keyword and upstream has no
`--perspective-none`.

**Confirmed against upstream's compiled output** (4.3.2): every step on
`ScaleX` and `ScaleY` (upstream's scale is functional over any integer), the
five `Rotate.Neg` magnitudes, the five `translate-y-*` rows the reference file
omits, and `§ 16.6`'s property.
**Reference gaps left undeclared**: `rotate-x/y/z-*`, `translate-z-*` and
`scale-z-*` — `§ 16` enumerates no 3-D axis variant. The both-axes `Translate`
section the front's Definition of Done lists (and its Step 3 table does not)
was added in the audit pass: `.Transform.Translate.{0,Px,1,Half,Full}` writes
both `--tw-translate-*` variables and the composition, upstream's
`translate-<n>`.

**`.Transition.Base`, never `.Transition.Default`** — `default` is in the
keyword table AND `Default(inner)` is already a top-level modifier variant, so
the name fails the head audit twice over. Four LEAVES of this front repeat a
head declared elsewhere (`Transition.All` beside `Pad.All`/`Gap.All`,
`Transition.Opacity` and `Transition.Shadow` beside `Effect.Opacity` and
`Effect.Shadow`); all four were RUN on both targets, with the other section's
leaf asserted beside them, rather than renamed to dodge a collision that does
not exist.

Front 46 owns **interactivity** — the `Interact` section of `tokens.bp` and the
three top-level colour variants `InteractAccent` / `InteractCaret` /
`InteractScrollbarColor`, and `interactTokenToCss` with its sub-dispatchers and
the wrappers `accent` / `caret` / `scrollbarColor` in `emilia.bp`, fenced by the
`// ── front 46 — interactivity ──` banner in both files. **161 leaves** over
`§ 17`. No leaf resolves a length or a colour: the fourteen scroll-offset
families answer `spacing(n)`, and the colour variants carry front 33's
`paletteVar` in their `string` payload. `cursor-default` is `Cursor.Standard`
(`Default(inner)` is a modifier); `accent-auto` is the nullary leaf
`Interact.AccentAuto` (decision 81). **The snap strictness is not a theme
entry** — the spec's `--tw-scroll-snap-strictness` default cannot be one
(`extendTheme` refuses `--tw-`), so `Snap.Type` reads it through `cssVarOr` with
upstream's initial value `proximity` as the fallback, and a `Snap.Strictness`
token in the same class overrides it.

Front 47 owns **SVG and accessibility** — the `Svg` and `A11y` sections of
`tokens.bp` and the top-level `SvgFill` / `SvgStroke` / `SvgStrokeWidthRaw`, and
`svgTokenToCss`, `a11yTokenToCss`, `srOnlyBody()` / `notSrOnlyBody()` and the
wrappers `fillColor` / `strokeColor` / `rawStrokeWidth` in `emilia.bp`, fenced by
the `// ── front 47 — svg and accessibility ──` banner in both files. **11
leaves.** `fill-current`/`stroke-current` are `currentcolor`, DERIVED from the
suffix (`§ 18` prints no value). **The `sr-only` gate is closed**: `§ 19.2`
prints no CSS, so both bodies were read from upstream's `utilities.ts` on
2026-09-26 and pasted in upstream's order; `not-sr-only` restores eight of the
nine properties, because upstream leaves `border-width` alone. Colours carry
front 33's `paletteVar`, never a hex.

The spec authors a richer surface (a `#[emilia(...)]` decorator on a
builder call + a `[emilia]={...}` attribute inside the `` html @`…` ``
DSL); both forms need the two generic rakun-bpp hooks (`F0` second
half — deferred). v0 ships the underlying mechanism without the two
attachment syntaxes.

## How it expands

- **Walk at runtime, not comptime.** v0's `emilia(tokens)` is an
  ordinary `pub fn`: the token array reaches the body as a runtime
  value (not a `comptime` argument); the `case t { … }` dispatcher fires
  per element. Promoting to comptime — so the consumer writes
  `#[emilia([.Bg.White])] div([])` and the class name + registration
  side-effect lower at compile time — needs the rakun-bpp
  annotation-on-builder hook (a generic mechanism) and the decorator
  body must be one of the new "call-site decorator" shapes that pass
  the call's argument list as a `comptime` value.
- **`Token[]` for the modifier payload.** The modifier variants
  (`Hover([Token]), Md([Token])`, …) recurse through `tokensToSheet` and
  wrap the inner sheet in a `Variant` (`nestVariant`): a selector template
  (`&:hover`) and/or an at-rule (`@media (width >= 48rem)`), so a modified
  token becomes a SIBLING rule of the class, never text nested in its body.
- **Lowering to JS.** v0 lowers to plain `function emilia(tokens) {
  ... }` + a host expression per `#[compiler.external(.<Target>(…))]` declaration. There is
  **no compiler change** beyond what was already in `feat` (`compiler.external`
  templates, `case`/exhaustiveness, enum payload destructuring with
  named fields).

## How it integrates with rakun-bpp (today and tomorrow)

- **Today.** A consumer does
  `import { emilia.emilia, flush, Token } from "rakun-stylesheet"`, calls `emilia(...)`
  to GET a class name, then composes the SSR output as
  `renderToString(page) + flush()`. v0's `Element` has **no attribute
  slot**, so the class name lives in the `<style>` block but is not
  yet inlined onto the rendered tag. The recorded follow-up there is
  the `Element` attribute carrier (rakun-bpp spec — there is already
  a tracked task), independent of emilia.
- **Tomorrow (deferred — `F0` second half + rakun-bpp spec):**
  - **Annotation-on-builder.** A generic rakun-bpp hook that recognises
    `#[<name>([…])] tag(children)` on a builder call and transforms it
    to `tag(children, attrs: [class: <name>(tokens)])`. emilia is one
    consumer (`<name>` = `emilia`); a future ecosystem lib (e.g.,
    data-attribute helpers) plugs into the same hook with no
    additional compiler change.
  - **`[name]={expr}` html attribute.** The html scanner sees
    `<tag [name]={expr}>`, looks up `name` in the registered
    annotation handlers (`emilia` here), passes `<expr>` to it, and
    replaces the attribute with `class={name(expr)}`. Generic — the
    html DSL knows nothing about emilia.

Both hooks are **emilia-agnostic** — rakun-bpp owns the mechanism.

## What emilia is NOT

- **Not a compiler change.** No new `#[@…]` annotation in the core, no
  AST node, no codegen hook. The entire DSL is `pub fn` + `case` +
  `#[compiler.external(.<Target>(…))]` — already shipped primitives.
- **Not a CSS processor.** emilia reads no author CSS: author CSS is the
  `css` library's, components are `styled`'s (decision 338), and emilia is
  the layer of typed tokens over them. No preprocessor pipeline. Since front
  56 a modifier is **not** a nested block: it is a
  `Variant` — an at-rule and a selector template with one `&` — and a
  modified token becomes a **sibling rule** hoisted out of the class
  body. Variants nest (`Md(Hover(...))`), and the outer one is outermost
  in the selector and in the at-rule list alike.
- **commonJS and erlang.** The `Stylesheet` host cell is a JS `Map` on
  commonJS and an ordered `[{Name, Body}]` list in the process dictionary on
  erlang (same `register`/`flush` contract); the class id is std's
  `hash.contentHash` (the djb2 fold over code points, unpadded lowercase hex)
  on both, so class names agree. `botopink test --target erlang`
  runs the suite, and it is the gate that catches a per-target divergence — see
  `Array.lastIndexOf` under § Maintainer rules. beam/wasm are not ported.

## Tree

> **In the rakun workspace** (front 165 s1) this package is `modules/rakun-stylesheet/`, and the tree below is the one it had as a repository of its own: its former `modules/*` are siblings in rakun's `modules/`, its cells are `conformance/emilia/`, its examples `examples/emilia/`, its refusals `refusals/emilia/`; the root manifest, `scripts/` (one gate, one hook), `.github/` and `.gitignore` are rakun's — read the tree for the package's own layout, never for those.

The repository is a **workspace** (decision 75 of 1.0.10-beta): the root
`botopink.json` declares members and is never a package — no `src`, `files`,
`entry` or `dependencies`; `botopink build`/`botopink test` there is the
located refusal `botopink.json is a workspace, not a package — run this
command inside one of its members: emilia, rakun-stylesheet, emilia-backgrounds, emilia-borders,
emilia-card, emilia-cascade, emilia-effects, emilia-grid, emilia-layout,
emilia-modifiers, emilia-outline-ring, emilia-spacing, emilia-text-decoration,
emilia-theme, emilia-transforms, emilia-transitions, emilia-typography`. Every `modules/*/`
and `examples/*/` holding a `botopink.json` is a member, named by its own
manifest. The **core is the member `modules/rakun-stylesheet/`**; `from "rakun-stylesheet"`
resolves to it, never to the umbrella.

```text
emilia/
├── AGENTS.md          ← you are here
├── conformance/       ← the reference and its examples (decision 463)
│   ├── docs.md        ← the user-facing token reference; each example is a
│   │                    `<!-- example: <cell> -->` line naming a cell
│   └── modules/<example>/  ← one cell per example of the reference, in the
│                        language suite's shape (decisions 457, 462, 475):
│                        `botopink.json` (`{ "name": "<cell>" }` — emilia, the
│                        targets and the version are the workspace's,
│                        `modules/botopink.json`) · `src/main.bp` · `snapshot/output/
│                        main.snap` (the answer, one for every target) ·
│                        `snapshot/targets/<t>/…` only where a target departs
│                        · `docs.md` (the reference text beside the cell).
│                        `botopink cell check conformance/` (from this
│                        directory) answers every cell; a candidate is accepted
│                        by renaming `*.snap.new`, never written by the tool
├── botopink.json      ← WORKSPACE: name emilia · version · targets
│                        [commonJS, erlang] (the default every member
│                        inherits and may only restrict) · workspaces
│                        ["modules/*", "examples/*"]. Nothing importable.
├── modules/
│   ├── rakun-stylesheet/   ← front 95: the test-helper member — `from "rakun-stylesheet"`;
│   │   │                files [root.bp], `emilia` via { "workspace": true };
│   │   │                EMPTY `pub` surface until the track-D fronts add the
│   │   │                `assert<Subject>(loc, …)` helpers
│   │   │                (`specs/05-emilia/modules.md`)
│   │   └── src/root.bp ← one inline `test` proving the core resolves from it
│   └── emilia/        ← THE CORE — what `from "rakun-stylesheet"` gives a consumer
│       ├── botopink.json  name emilia · src src/ · entry root.bp ·
│       │                    target commonJS · targets [commonJS, erlang] ·
│       │                    files: root.bp · tokens.bp · theme.bp ·
│       │                    spacing.bp · output.bp · preflight.bp ·
│       │                    arbitrary.bp · container.bp · compose.bp ·
│       │                    attributes.bp ·
│       │                    emilia.bp · no dependencies (std is implicit:
│       │                    `emilia.bp` imports `{hash}` for the class id)
│       └── src/
│           ├── root.bp    ← `pub mod tokens; pub mod theme;
│           │                pub mod spacing; pub default mod emilia;` (the
│           │                v0 build folded the `stylesheet` module into
│           │                `emilia.bp` — see the README's "Deferred")
│           ├── theme.bp   ← front 54: the theme as a FLAT `ThemeEntry[]`
│           │                with validated namespace prefixes (`Ns` +
│           │                `nsPrefix`, the only place a prefix is
│           │                written), `DarkMode`, `defaultTheme()`, and
│           │                the extendTheme / clearNamespace /
│           │                emptyTheme / namespace / themeValue /
│           │                themeVar operations
│           ├── spacing.bp ← front 54: `spacing(n)` = `calc(var(--spacing)
│           │                * n)`, `spacingHalf(n)` and `spacingNegHalf(n)`
│           │                (`-0.5` is `spacingNegHalf(0)`; `spacingHalf`
│           │                refuses a negative whole part). emilia NEVER
│           │                resolves a spacing value. Front 35 deleted
│           │                six of the seven `rem` ladders that were in
│           │                `emilia.bp`; the seventh, `flexGapScale`, is
│           │                `Flex.Gap`'s and is front 37's. Every
│           │                `*.Neg.Half` is `{0,1,2,3}`
│           ├── preflight.bp ← front 55: `preflightRules()` — eleven
│           │                `base`-layer rules with literal selectors
│           │                covering `§ 4`'s eight bullets (parity, NOT
│           │                byte-equality with upstream `preflight.css`) —
│           │                and `preflight()`, the same as a CSS fragment.
│           │                Opt-in only: `withBase(o, preflightRules())`
│           ├── arbitrary.bp ← front 57: the six `Arb*` escape hatches' validating
│           │                builders (`arbValue`, `arbProp`, `arbSel`, `arbAt`,
│           │                `arbMin`, `arbMax`), their dispatcher helpers, the
│           │                run-time reject sets (`refusesValue` …) and the five
│           │                comptime validators (`cssValue`, `cssIdent`,
│           │                `cssSelector`, `cssQuery`, `cssLength`)
│           ├── container.bp ← front 58: `ContainerSize` + `containerKey` (the
│           │                only place a size key is written), the thirteen
│           │                `containerAt<Size>(inner)` builders, `containerNamed`,
│           │                `containerName`, and `containerAtRule`, which reads
│           │                `--container-*` from the theme and panics on a size
│           │                it does not define
│           ├── compose.bp ← front 59: bundles are `Token[]` functions
│           │                (`scrollbarHidden`), `compose` is `@apply`,
│           │                `hocus`/`selector`/`themeMidnight` are custom
│           │                variants (`named(class, tokens)` is in `emilia.bp`,
│           │                beside the cell it registers into). No external,
│           │                no `Token`, no arm, no compile-time block
│           ├── attributes.bp ← front 48: the class-name CONTRACT (its header,
│           │                contract 4 word for word), `mergeClass` — the one
│           │                static-first merge in the workspace — and
│           │                `nonAsciiIn`. The slot itself (`className`,
│           │                `styled`, `styledWith`, `cls`, `clsWith`,
│           │                `assertAsciiBody`) is in `emilia.bp`, beside the hash
│           ├── output.bp  ← front 56: the rule model (`Rule`, `Block`,
│           │                `Sheet`, `Variant`), `nestVariant` /
│           │                `markImportant`, the `\t`/`\n`/`\r` codec that
│           │                carries a `Sheet` through the string-keyed host
│           │                cell, `Options` + the five `with…`, and
│           │                `renderRule` / `renderDocument`. It declares NO
│           │                external and imports only `theme` — the cells
│           │                cannot move here (see "Gotchas")
│           ├── tokens.bp  ← the `Token` enum-shaped `type`
│           │                (`pub type Token { … }`): every section + the
│           │                modifier variants. Section headers live in
│           │                the docblock. A line comment inside the enum
│           │                body USED to be a parser gotcha; front 35
│           │                measured it green (`botopink test` both
│           │                targets + every example) and its banner
│           │                fences `Pad`/`Margin`/`Size`/`Space` inside
│           │                the body. Prefer the docblock anyway
│           └── emilia.bp  ← `emilia(tokens) -> string` + `flush()` + the
│                            `tokenToCss`/`tokensToCss` dispatchers + the
│                            `#[compiler.external(.<Target>(…))]` host cells
│                            (`register`, `flushSheet`) + the 17 inline
│                            tests. It imports `Token` as
│                            `import {tokens.Token};` — naming the
│                            sibling module is **required**, see "Gotchas"
├── examples/
│   ├── emilia-borders/ ← member `emilia-borders` (an application: entry
│   │                    main.bp, targets [commonJS, erlang], `emilia` via
│   │                    { "workspace": true } — the front 40 showcase for
│   │                    `Border`: one width per side and the two axes, the
│   │                    logical `S`/`E` pair, the six styles, the palette
│   │                    reaching `border-color` WITH its shade, the radius
│   │                    ladder as `var(--radius-*)`, side and corner radii,
│   │                    and a table-like card with a rounded top, a square
│   │                    bottom and a dashed internal rule. 10 in-file
│   │                    `test {}`, green on both targets)
│   ├── emilia-outline-ring/ ← member `emilia-outline-ring` (an application:
│   │                    entry main.bp, targets [commonJS, erlang], `emilia`
│   │                    via { "workspace": true } — the front 40 showcase for
│   │                    the three families that had no token at all: the four
│   │                    outline properties, the `outline-none` trap asserted
│   │                    in BOTH directions, a ring as a custom property plus a
│   │                    composed `box-shadow`, the ring offset and inset, a
│   │                    ring and a shadow in one list swapped both ways for
│   │                    contract 4, and a divided list whose class body is
│   │                    EMPTY because every declaration is on a child.
│   │                    13 in-file `test {}`, green on both targets)
│   ├── emilia-cascade/ ← member `emilia-cascade` (an application: entry main.bp,
│   │                    targets [commonJS, erlang], `emilia` via
│   │                    { "workspace": true } and NOTHING else — it is the
│   │                    front 56 showcase: one card whose hover is a sibling
│   │                    rule, whose breakpoint is a hoisted `@media` read from
│   │                    the theme, whose reset arrives through `Options` in its
│   │                    own `base` layer, and whose document is layered so a
│   │                    project's own CSS can beat a utility deliberately.
│   │                    10 in-file `test {}`, green on both targets)
│   ├── emilia-theme/  ← member `emilia-theme` (an application: entry main.bp,
│   │                    targets [commonJS, erlang], `emilia` via
│   │                    { "workspace": true } and NOTHING else — it is the
│   │                    front 54 showcase and the proof that the theme
│   │                    surface crosses a package boundary through
│   │                    `from "rakun-stylesheet"`. 6 in-file `test {}`; the flushed
│   │                    document does NOT yet carry the theme — wrapping
│   │                    `themeCss`/`keyframeCss` in cascade layers is
│   │                    front 56's `withTheme`/`flushWith`)
│   ├── emilia-spacing/ ← member `emilia-spacing` (an application: entry
│   │                    main.bp, targets [commonJS, erlang], `emilia` via
│   │                    { "workspace": true } — the front 35 showcase: the
│   │                    multiplier scale, nine padding and margin
│   │                    directions, `auto`, negatives, child spacing, the
│   │                    thirteen `Size` sub-sections, and a centred article
│   │                    shell with a full-bleed header. Its last test is
│   │                    the front's whole argument: halving `--spacing`
│   │                    moves the `:root` block and not one byte of any
│   │                    rule. 12 in-file `test {}`, green on both targets)
│   ├── emilia-modifiers/ ← member `emilia-modifiers` (an application: entry
│   │                    main.bp, targets [commonJS, erlang], `emilia` via
│   │                    { "workspace": true } — the front 34 showcase: a
│   │                    responsive dark-surfaced nav whose links read the
│   │                    bar's hover through `.group`, a field whose error is
│   │                    shown by its SIBLING's invalid state, a table striped
│   │                    by Odd/Even/Nth with one Important declaration, and
│   │                    one panel under all three DarkMode strategies. 16
│   │                    in-file `test {}`, green on both targets)
│   ├── emilia-layout/ ← member `emilia-layout` (an application: entry main.bp,
│   │                    targets [commonJS, erlang], `emilia` via
│   │                    { "workspace": true } — the front 36 showcase: the
│   │                    eleven display values, the nine inset directions and
│   │                    the four shapes of an inset leaf, overflow on three
│   │                    properties, the two name-versus-value traps in one
│   │                    rule, the column ladder as the container ladder, a
│   │                    media card that crops its image and clips its
│   │                    overflow, and a sticky header over a scrolling panel
│   │                    with a badge on a negative inset. Its last two tests
│   │                    are the front's argument: no layout token in it
│   │                    resolves a length, and halving `--spacing` gives the
│   │                    same class with the same declarations. 12 in-file
│   │                    test {}, green on both targets)
│   ├── emilia-backgrounds/ ← member `emilia-backgrounds` (an application:
│   │                    entry main.bp, targets [commonJS, erlang], `emilia`
│   │                    via { "workspace": true } — the front 39 showcase:
│   │                    the seven keyword sub-sections of `Bg`, the eight
│   │                    gradient directions, a hero panel whose photograph
│   │                    covers and anchors, a gradient call to action, a
│   │                    three-stop banner whose `Via` is listed after its
│   │                    `From`, a gradient-text heading built with
│   │                    `bg-clip-text`, and a texture that tiles on one axis.
│   │                    Its last two tests are the front's argument: a
│   │                    project's indigo reaches the gradient stop and the
│   │                    background alike, and nothing it emits resolves a
│   │                    colour or a length. 12 in-file test {}, green on both
│   │                    targets)
│   ├── emilia-typography/ ← member `emilia-typography` (an application: entry
│   │                    main.bp, targets [commonJS, erlang], `emilia` via
│   │                    { "workspace": true } — the front 38 showcase for the
│   │                    FONT half of `§ 9`: the three families as theme
│   │                    references, a size token as the two-declaration pair,
│   │                    the four weights the ladder was missing, smoothing,
│   │                    not-italic, font-stretch, a tabular slashed-zero figure
│   │                    set, tracking and leading with `leading-none`'s
│   │                    literal, line-clamp and its four-declaration reset,
│   │                    `truncate`, and an article header over a clamped
│   │                    excerpt. Its last two tests are the front's argument: a
│   │                    project's `--text-4xl` and `--font-sans` reach the
│   │                    header and give the SAME class, and nothing it emits
│   │                    resolves a size, a leading or a font stack.
│   │                    11 in-file `test {}`, green on both targets)
│   ├── emilia-text-decoration/ ← member `emilia-text-decoration` (an
│   │                    application: entry main.bp, targets [commonJS,
│   │                    erlang], `emilia` via { "workspace": true } — the
│   │                    front 38 showcase for the TEXT half: the four
│   │                    decoration lines on the longhand with the shorthand
│   │                    asserted ABSENT, a line composing with a style (which
│   │                    the shorthand made impossible), thickness and offset,
│   │                    the palette on `text-decoration-color` with three
│   │                    shades giving three classes, lists, whitespace,
│   │                    word-breaking beside overflow-wrap, hyphens, indent as
│   │                    a spacing multiplier, vertical-align, tab-size,
│   │                    `content:""` on a `::before`, and a footnoted
│   │                    paragraph whose links are wavy-underlined.
│   │                    11 in-file `test {}`, green on both targets)
│   ├── emilia-effects/ ← member `emilia-effects` (an application: entry main.bp,
│   │                    targets [commonJS, erlang], `emilia` via
│   │                    { "workspace": true } — the front 41 showcase: the
│   │                    box-shadow scale as a theme reference where it used to
│   │                    emit the Tailwind class suffix, inset and text shadows,
│   │                    the twenty-one opacity steps, both blend-mode families
│   │                    and the nine mask properties, ending in a photo card
│   │                    that layers a shadow, a blend mode and an opacity under
│   │                    a hover. 12 in-file `test {}`, green on both targets.
│   │                    ADDED TO THIS TREE BY FRONT 44 — front 41 landed the
│   │                    member and not the line
│   ├── emilia-transitions/ ← member `emilia-transitions` (an application: entry
│   │                    main.bp, targets [commonJS, erlang], `emilia` via
│   │                    { "workspace": true } — the front 44 showcase: the six
│   │                    preset bundles as three declarations from one token,
│   │                    `allow-discrete`, the two nine-step ms ladders with
│   │                    `0ms` keeping its unit, the easings as theme references
│   │                    a project overrides without moving a class, the four
│   │                    built-in animations with their hoisted `@keyframes`
│   │                    blocks (and two spinners hoisting ONE), a custom
│   │                    animation that hoists none, and a submit button whose
│   │                    colours move over 200ms on hover and which dims and
│   │                    grows a spinner while the form is in flight.
│   │                    14 in-file `test {}`, green on both targets)
│   ├── emilia-transforms/ ← member `emilia-transforms` (an application: entry
│   │                    main.bp, targets [commonJS, erlang], `emilia` via
│   │                    { "workspace": true } — the front 45 showcase: the five
│   │                    rotations and the five a `Neg` sub-section spells, the
│   │                    ten scale steps and the two-value axes, the ten
│   │                    translate rows with the other axis as a fallback, skew
│   │                    on UPSTREAM's property with the reference file's column
│   │                    asserted absent, the nine origins, the
│   │                    `transform-3d` → `preserve-3d` trap, the perspective
│   │                    family as `--perspective-*` references a project
│   │                    overrides without moving a class, the two decimal
│   │                    conventions side by side, upstream's `transform-gpu`
│   │                    row, the two escape hatches, and a card that
│   │                    lifts and grows on hover beside a chevron that flips
│   │                    180° when its disclosure opens. 18 in-file `test {}`,
│   │                    green on both targets)
│   └── emilia-card/   ← member `emilia-card` (an application: entry main.bp,
│                        targets commonJS and erlang, `emilia` via
│                        { "workspace": true } and nothing else — decision
│                        114): prints the three class names `emilia(…)`
│                        answers for one card's token lists (one with a
│                        Hover/Md modifier) and the flushed document; 4
│                        in-file `test {}` pinning both, green on both
│                        targets
└── scripts/
    └── git-hooks/     ← the pre-commit gate (§ Local gate): staged files
                         (no snapshot candidate, no conflict marker), the
                         compiler (absent → refused), then `botopink test`
                         in every workspace member on every target its
                         manifest declares, then `botopink build` of every
                         example on every declared target (no list of
                         examples allowed to fail), then `refusals/*/`
                         (none today); the runner is one text in the five
                         library repositories
```

`modules/rakun-stylesheet/` is the `<lib>-test` member front 95 created empty; it
stands on std's `asserts` and `snapshots`, re-exports nothing from std, and
`02-packaging` step 4 / the track-D fronts give it its first
`assert<Subject>(loc, …)`.

`.d.bp` files are NOT in the module tree (memory:
`project_libs_module_migration_done`); emilia has none today.

`.github/workflows/test.yml` — CI: the rows are the manifests' target set
(gate-j of 1.0.11-beta `00-gate`) on the runners the compiler is gated on:
`ubuntu-24.04 × {commonJS, erlang}` (no macos row), against botopink-lang
`vars.BOTOPINK_LANG_REF` (default `feat`). Every row is hard — no
`allow_fail`, no `continue-on-error`. No `beam` row (`botopink test` cannot
run beam) and no windows row (gate-f: botopink-lang's own workflow has none,
so a row here would measure the compiler's windows port; it returns with the
compiler's). The linux runner is `ubuntu-24.04`; the compiler links against a
pinned glibc 2.35 (decision 219, ubuntu-22.04's), so it starts on either
runner — the 22.04 floor is the compiler's own workflow's. Erlang/OTP 28 **and** Node 22 are installed on every
row (OTP 28 pinned on the runner — the release the root `botopink.json`'s `"otp"` names (`"28"`), read by a step before the installs (decision 228; the compiler refuses any other `erl` on PATH) — `erlef/setup-beam` (decision 227), and a step after it fails the job unless `erl` reports that release) — `zig build install` runs `erlc` and comptime evaluation spawns `erl`
whatever the row's target. Each row is one `botopink-lib-test --bin
"$BOTOPINK_BIN" --target <t> --strict` from a scratch directory with
`BOTOPINK_LIB_ROOTS` naming this repository, so the runner discovers this
workspace's 17 members — `modules/{emilia,rakun-stylesheet}` and the fifteen
`examples/*`, one row each — and nothing else: the compiler's `libs/std` is a
dependency, not a row (run from inside the checkout it would be). No other
library is checked out: every member depends on `emilia` (or nothing) only
(decision 114; the rakun-bpp checkout `emilia-card` needed went with 1.0.12-beta
`00-gate/114` step 8). The hook's other stages then run from the hook's own
runner on every row: `runRepositoryStagesGate` (no `repository-stages.sh`
here), `runExamplesGate "$bin" <t>`, `runRefusalsGate` (no `refusals/` here).

## Maintainer rules

- **A variant selector carries exactly ONE `&`, and a reference row that
  carries two is the reference's problem.** `§ 3.2` spells `open` as
  `&:open, &:popover-open`; front 56's `checkVariantSelector` refuses it, and it
  is right to — a two-`&` template duplicates the rule it wraps, which is a
  stylesheet that is silently wrong in a browser days later. The fix is a
  selector, not an escape hatch: the states go inside one `:is()` — upstream
  v4's `&:is([open], :popover-open, :open)`, legacy `[open]` attribute first —
  which matches the same elements through one `&`; `group-open:` carries the
  same three. `rtl:` / `ltr:` are upstream v4.1's `&:where(:dir(rtl),
  [dir="rtl"], [dir="rtl"] *)`, one leading `&`. A row upstream writes as a
  selector LIST whose members cannot share one `&` — `marker:` (`& *::marker,
  &::marker`, plus the two `::-webkit-details-marker`) and `selection:` — is a
  LIST OF ONE-`&` VARIANTS (`markerVariants()`, `selectionVariants()`) that
  `nestVariants` wraps once each, in upstream's order: several rules, never a
  two-`&` template.
- **`markImportant` is not a `Variant`, so `Important` is not a variant arm.**
  Its arm answers `markImportant(tokensToSheet(inner, th))` and it adds no
  selector and no at-rule; it also produces ONE RULE PER INNER TOKEN, so a test
  over two tokens reads two rules rather than one rule of two declarations.
- **camelCase** all method/fn names (`tokenToCss`, `flushSheet`,
  `styleRule` — never `token_to_css` — memory:
  `feedback_camelcase_naming`).
- **A payload leaf NESTED INSIDE A SECTION cannot be constructed.**
  `Token.Color.Hex("#abc")` reds `'Hex' is not declared in any behavior
  implemented for 'Token'`; `val h: Token = .Color.Hex("#abc");` reds `unbound
  variable 'Color'`. The variant type-checks in a `case` pattern, so the
  surface looks complete and is not — `Color.Hex`, `Bg.Hex` and
  `Border.Color.Hex` are all reachable by an arm and by nothing else. A
  payload-carrying token has to be a **top-level** variant with builtin-typed
  fields (`Token.Alpha(percent: i32, inner: Token[])`, `Token.Hover(inner:
  Token[])`), which is what contract 4a requires of every one in the milestone.
- **Enum payload destructuring uses the NAMED FIELD** —
  `ColorHex(value: string)` is matched as `ColorHex(value) -> …`, not
  `ColorHex(v) -> …`. The positional binding parses but lowers to
  `undefined` (codegen relies on the field name to project the payload
  from the runtime variant record).
- **No line comment inside an enum body** (kept from the 1.0.2 parser; the
  1.0.3 field list accepts comments, but the body stays comment-free).
  Section headers go in the module docblock.
- **`botopink format` is applied to every source, `tokens.bp` included.** It
  used to reorder the authored `Token` body — payload variants printed before
  the sections — which is why this line once excluded the file. botopink-lang
  `37d3dc7` records member positions and no longer reorders, and decision 34
  withdrew the exemption. It is **red today** and was red before the workspace
  migration: `botopink format --check` in `modules/rakun-stylesheet/` prints `Formatted
  src/emilia.bp` (`root.bp` and `tokens.bp` unchanged) and
  `examples/emilia-card/` prints `Formatted src/main.bp` — the formatter moved
  under the compiler since the last `style(src)` sweep. Reformatting is a
  source change and belongs to a `style(src)` commit, not to a packaging one.
- **FIXED — `.Color.Red.500` and five siblings used to be DECLARED AND
  UNREACHABLE.** The compiler resolved a leading-dot section path
  (`tryResolveEnumSectionPath`, compiler-core `comptime/infer.zig`) by iterating
  `env.typeDefs` — which holds the synthesised section enums beside the real
  ones — and returning the first enum whose section tree carried the path,
  never consulting the expected type. `Token` carries `Color.Red.500` and so
  does `__Token__Border` (`Token.Border.Color`, whose Red and Gray run
  100/500/700), so hash order decided, and it decided against us for
  `.Color.Red.{100,500,700}` and `.Color.Gray.{100,500,700}`: every spelling
  red, including the fully qualified `Token.Color.Red.500`, which the resolver
  did not accept at all. It failed loudly (`type mismatch: expected Token, got
  __Token__Border`) rather than emitting the wrong CSS, and it flipped whenever
  the typedef set grew. botopink-lang `f01c508a` now prefers the enum the
  expected type names, accepts the fully qualified spelling, and refuses an
  ambiguous path naming both candidates instead of picking one; emilia
  `1cd39b2` asserts all six cells, and the two palette tests went from eight
  shades to eleven. **The standing rule survives the fix**: never resolve a
  collision like this by adding or renaming a type to flip the hash order —
  that is invisible, and the next front re-breaks it.
- **A section of `Token` is a type written by its path** — `Token.Text`,
  `Token.Text.Size`, `Token.Border.Color` (botopink-lang decision 8 §5.3b).
  The flat spelling (`TokenText`) names nothing and reds with a hint; a
  sub-dispatcher takes its own section, never the whole `Token`, so its
  `case` stays exhaustive without a `_` and a new member reds it.
- **Array type spelling is postfix** — `Token[]`, NOT `[Token]`. The
  prefix bracket parses only as an array literal (`[Token.PadX4]`).
- **`from "rakun-stylesheet"` only**, never a relative module path and never the
  directory. The name resolves to the member `modules/rakun-stylesheet/`, which is what
  `emilia-card` reaches through `{ "emilia": { "workspace": true } }` and what
  an outside consumer reaches through the git form — a member is reached by
  its manifest `name`, never by its path (decision 75).
- **Cross-module `#[compiler.external(.<Target>(…))]` symbol imports don't lower at v0** —
  `import { register };` from a sibling module resolves the type but
  the runtime symbol is `undefined`. Until the codegen path closes
  that gap, keep all `#[compiler.external(.<Target>(…))]` host-cell expressions in the
  module that USES them (currently `emilia.bp`).
- **`extend` is a language keyword, so the theme's composer is `extendTheme`.**
  `Name extend Type { … }` is the type-extension block, which makes `fn
  extend(…)` a parse error (`unexpected \`extend\``) — the front 54 spec, front
  33's and front 56's all write `extend`, and none of them parses. Every front
  that composes a theme writes `extendTheme`.
- **A lambda whose whole body is an `if` expression returns `undefined` on
  commonJS.** `xs.map({ x -> if (c) { a } else { b } })` lowers to
  `(x) => { (() => { … })(); }` — the IIFE is emitted as a statement and its
  value is never returned. erlang is unaffected, so the suite is green on one
  target and silently wrong on the other. Bind the branch to a `val` and yield
  it (`val out = if (c) { a } else { b }; out;`). Reported to botopink-lang as a
  codegen defect (the commonJS lambda tail-expression path).
- **`String.contains` does not lower inside a lambda over an inferred
  element.** `xs.filter({ e -> e.name.contains("x") })` emits `.contains(…)`
  verbatim on commonJS (`e.name.contains is not a function`) because the
  `contains` → `includes` rename runs off a receiver type the inferencer has not
  resolved inside the lambda; a direct receiver (`s.contains(…)`) and a record
  field outside a lambda both work. Hoist to a typed `val`, or use `endsWith` /
  `indexOf(…) != -1`.
- **FIXED — the commonJS `String` prelude's `charCodeAt` patch used to be
  self-recursive.** The backend installs the whole `String` behavior prelude
  into any module that uses a member needing a patch — `slice` is one,
  `split`/`indexOf`/`startsWith` are not — and that prelude wrote
  `String.prototype.charCodeAt = function(index) { return
  ((this.valueOf().charCodeAt(index) ?? -1) | 0); }`, which called the patch it
  had just installed. One `s.slice(…)` anywhere in a module therefore made every
  `.charCodeAt(…)` in the PROGRAM blow the stack — emilia's former hash template
  did, so every non-empty class body did. **The ban on `String.slice` in this
  library is lifted**: botopink-lang's prelude now calls `codePointAt`, which
  also fixed a second defect the first was hiding (the `?? -1` was dead, since
  native `charCodeAt` answers `NaN`, so commonJS answered `0` out of range where
  erlang answered `-1`), and a test now walks the embedded prelude and fails if
  any template calls the method it patches. Code that split on a separator to
  avoid `slice` is correct as written and need not be unwound.
- **FIXED — a `case` arm over a uniquely-named variant used to lower to
  `instanceof`, which does not cross a package boundary.** The commonJS backend
  lowered an arm whose variant name was unique in the program to `_s instanceof
  __Token__Text__Size$X3xl` and an arm whose name repeated to `_s.tag === "Lg"`.
  A consumer package **re-emits its own copy** of the enum classes, so a value
  built in `examples/emilia-card/` was never `instanceof` the class `emilia`
  matched against: the `case` fell through every arm and answered `undefined`,
  which is why `.Text.Size.X3xl` and `.Text.Size.Base` were missing from that
  example's class bodies. It was invisible inside emilia's own suite, where
  there is one copy of the classes. botopink-lang now compares the `tag` string
  for a uniquely-named variant too; the example asserts the full class bodies
  and is green. Kept here as the reason a cross-package `case` is worth a
  runnable example.
- **FIXED — `Array.reverse()` used to mutate its receiver on commonJS and not on
  erlang.** `val rev = xs.reverse();` left `xs` reversed on commonJS (native
  `Array.prototype.reverse` is in-place and the codegen called it directly) and
  untouched on erlang (`lists:reverse/1` is pure), so code reading the receiver
  again answered differently per target — green on one, silently wrong on the
  other. botopink-lang now emits `toReversed()`, which answers a new array. The
  workaround in `output.bp`'s `wrapAtRules` (mapping the list twice) is no
  longer required and may be simplified by whichever front next touches it.
  Kept as the reason a per-target divergence is worth a cell rather than a note.
- **`Array.lastIndexOf` did not lower on erlang** (`function lastIndexOf/2
  undefined` — a HARD error, invisible until the second target ran). It is
  declared and lowered on every target now; the duplicate checks written around
  it still count occurrences (`decls.filter({ x -> x == d }).length > 1`), which
  is correct and may stay. **Run `botopink test --target erlang` before every
  commit**, not only at the end of a front.
- **A front that turns a LITERAL into a REFERENCE must grep for its own tokens
  in other fronts' CONTROLS.** A "no leaf resolves a length" walk is paired with
  a control asserting some real token DOES carry one, so the probe is known to
  discriminate. Fronts 36, 37 and 39 all chose `.Border.Rounded.Lg` for that,
  because it spelled `0.5rem` — and front 40's whole job was to make it
  `var(--radius-lg)`. Three tests in two other fronts went red at once, and the
  front's own README had stated that no existing assertion covered `Sm`, `Md` or
  `Lg`. The controls then pointed at `.Text.Size.Lg`, which spelled
  `1.125rem` — and **front 38's whole job was to make THAT `var(--text-lg)`**,
  so the same walks (36's, 37's, 39's and by then 40's) went red a second time,
  exactly one front later. **There is now no token in emilia that resolves a
  `rem` at all** — which is the point of fronts 35–47, and also means a
  token-shaped control for that probe no longer exists. All four are now
  hand-built declarations (`f38CarriesNoLiteral("font-size:1.125rem") == false`)
  paired with the same fact asserted from the other side, so the walk still
  reddens the day a front reintroduces a resolved length. **A probe that takes
  a declaration STRING takes a string control**; reach for a real token only
  when your front does not own the family and no near-term front does — twice
  now, one did.
- **A SECTION HEAD may not be named like a TOP-LEVEL payload variant.** A
  section named `After` beside the top-level `After(inner: Token[])` does not
  red — it silently breaks the TOP-LEVEL variant's payload projection, so
  `Token.Before(inner)` builds a record with no `inner` field and the first
  thing to touch it dies on `Cannot read properties of undefined (reading
  'fold')`. The crash lands in the OTHER front's tests, with nothing pointing
  at the section that caused it. Front 36 hit this with
  `Layout.Break { After, Before, Inside }` against front 34's `After`/`Before`
  modifiers; the fix is the flat `Layout.BreakAfter` / `BreakBefore` /
  `BreakInside`, and not one byte of emitted CSS changed. **LEAF names are
  safe** — `Columns.Md` and `Size.MaxW.Md` coexist with the `Md` modifier and
  always have; it is the HEAD that shadows. Check a new section's name against
  the top-level variant list before adding it. Reported to botopink-lang: a
  name that cannot be constructed should not capture a constructor that can.
  **A HEAD BESIDE ANOTHER HEAD IS SAFE**, and front 41 is the front that ran it
  rather than assuming it: `Blend.Bg` sits beside the top-level section `Bg`
  and `Mask.Size` beside the top-level section `Size`, both resolve, both
  dispatch, on commonJS and on erlang. `Border.Color` has coexisted with the
  top-level `Color` since front 40 and four more sub-sections do the same. So
  the audit is against the PAYLOAD variants and the keyword table only — a
  section head may repeat a section head, and renaming to dodge one costs a
  path and buys nothing.

- **NEVER `s.split("")` A STRING THAT MAY CARRY NON-ASCII.** On erlang
  `"a→b".split("")` answers `["a"]` — everything from the first non-ASCII
  codepoint on is dropped — so a character scan written that way ADMITS the very
  payload it exists to refuse (front 57's ident and length reject sets were, and
  front 48's ASCII gate would have been). Remove each allowed character from the
  string instead (`arbitrary.bp`'s `residue`): the allowed set is ASCII, so
  splitting IT is safe. Reported with a one-file repro.
- **A SIBLING MODULE MAY NOT IMPORT `from "rakun-stylesheet"`.** Inside the package
  `"emilia"` names the default module `emilia.bp`, and a sibling importing it
  compiles and passes `botopink test` in `modules/rakun-stylesheet/` — and does NOT
  resolve when emilia is a DEPENDENCY: every example failed with `unbound
  variable 'flushWith'` in `emilia/preflight.bp`. So `preflight.bp`,
  `arbitrary.bp`, `container.bp` and `compose.bp` import `tokens`, `theme`,
  `output` and each other only; whatever needs `tokensToSheet`, the host cell or
  a flush lives in `emilia.bp` (the `Token[]`-carrying helpers take the inner
  list already folded to a `Sheet`, and the rendering tests sit under each
  front's banner in `emilia.bp`). **Run one example after adding a module** —
  the core suite cannot see this.
- **A DUPLICATE TOP-LEVEL `fn` IS NOT REFUSED BY THE CHECKER.** Two `fn
  bareOptions()` in `emilia.bp` passed commonJS (the second wins) and broke the
  erlang build (`function bareOptions/0 already defined`). Reported with a
  one-file repro; until the checker refuses it, the erlang run is what catches it.
- **An imported `selector` fn did not resolve inside `emilia.bp`** (`type
  mismatch: expected Token, got string` at the call); `import {selector as
  customVariant} from "compose"` works. Not reduced to a minimal repro — a
  two-module attempt passed.

- **AN IMPORTED ENUM THAT SHARES A VARIANT NAME WITH `Token` CAPTURES
  `Token.<Variant>(…)`.** Importing `ContainerSize` (whose `Sm`, `Md`, `Lg`, `Xl`,
  `X2xl` are also top-level `Token` modifiers) into `emilia.bp` made every
  `Token.Sm(inner)` in the module red with `type mismatch: expected Token, got
  ContainerSize` — the fully QUALIFIED spelling resolved to the other enum. It
  fails loudly, at the right line. `emilia.bp` therefore does not import
  `ContainerSize`, and a consumer that imports both `Token` and `ContainerSize`
  hits the same wall: write the size builders (`containerAtSm(inner)` …) and
  keep `ContainerSize` out of a module that spells `Token.Sm(…)`. Reported to
  botopink-lang with a three-file repro.

- **`Self` IS A LANGUAGE KEYWORD, so a section cannot be named it.** `Flex.Self
  { Auto, … }` reds `this token cannot appear here — unexpected \`Self\`` at the
  declaration and again at every `case` arm that names it. Unlike the
  section-head shadow below, this one FAILS LOUDLY and at the right line, so it
  costs a rename and nothing else. Front 37's `align-self` and `place-self`
  families are `Flex.AlignSelf` and `Flex.PlaceSelf`, and the rest of the
  `place-*` family is flattened with them — `Flex.PlaceContent` /
  `Flex.PlaceItems` — the way front 36 flattened `Break`, because half a
  flattened family reads worse than all of it. The spec's `.Flex.Self` and
  `.Flex.Place.Self` spellings do not parse; no emitted byte differs.

- **FIXED — a record type name used to shadow an enum LEAF of the same name,
  and the `case` arm over it went DEAD.** `output.bp` declares `pub type
  Block(header, body)` and `tokens.bp` the leaf `Layout.Block`; on a compiler
  before botopink-lang `ef2604af` the arm `Block -> "display:block"` in
  `layoutTokenToCss` matched nothing, the `case` fell through, and
  `.Layout.Block` answered the EMPTY STRING on commonJS while erlang stayed
  right. **It is fixed and needs no workaround** — `modules/rakun-stylesheet` is 313/313
  on `e22cf80` unmodified, with the plain `Block ->` pattern, on both targets.
  Front 39 briefly carried a `Block() ->` workaround measured against a STALE
  BINARY and reverted it once the compiler was rebuilt; **do not reintroduce
  it**, and do not audit a new leaf against the module's record type names —
  that rule was written from the same stale measurement and is not true.
  Kept because the failure MODE is the thing worth recognising, not the
  instance: a shadowed pattern does not red, it falls out of the `case` and the
  token declares nothing, on one target only. The section-head rule above is
  the form of it that is still live, and front 39's 910-leaf walk asserts every
  leaf declares something non-empty for exactly this reason.
  Measured on `ef2604af`, not inferred: a throwaway `type Grid(a: string)`
  beside the existing leaf `Layout.Grid` now leaves `.Layout.Grid` green, where
  on the stale binary the same probe reddened it.

- **`val x: Token.<Section> = .Leaf;` does not resolve — for ANY leaf — and a
  record sharing the name only changes the error TEXT.** The single-segment
  leading-dot form in a section-typed context reds `unbound variable 'Grid'`
  and `unbound variable 'Hidden'`; the same line written `.Block`, where
  `output.bp` has a record of that name, reds `type mismatch: expected
  __Token__Layout, got function` instead, because the record's constructor is
  the thing in scope. The differing message is misleading and cost this library
  a wrong diagnosis once: it reads like a shadow and is a general limitation.
  A section leaf is written from the enum root — `.Layout.Block` as a `Token`,
  never `.Block` as a `Token.Layout`.

- **A consumer must import a type's TRANSITIVE types too, and the error points
  at the wrong line.** `import { Theme } from "rakun-stylesheet";` alone reds `unknown
  type 'DarkMode'` because `Theme` carries a `DarkMode` field; `Options` needs
  `Rule`, `Block` and `Sheet` imported beside it for the same reason. Neither
  name is written anywhere in the consumer. Worse, the reported location is a
  COMMENT several lines away from any import — `src/main.bp:59:15` pointing
  into a banner — so the message is the only usable signal. The working import
  block for an example that touches the theme and `Options` is the one
  `examples/emilia-spacing/` and `examples/emilia-layout/` share:
  `{Theme, ThemeEntry, DarkMode, defaultTheme, extendTheme}` plus
  `{Rule, Block, Sheet, Options}`. Copy it rather than rediscover it.

- **A sibling-module import always names its module** — by its path inside the
  braces, `import {tokens.Token};` (decision 206: `from` names a package, never
  a module of emilia), never the bare `import { Token };`. Both type-check, but commonJS
  lowers the bare form to `require("../module")`: a path that resolves while
  emilia is compiled on its own and not when it is a dependency, which is how
  `examples/emilia-card` came to build and then die with `Cannot find module
  '../module'`. Reported to botopink-lang as a codegen defect
  (`src/codegen/commonJS.zig`, the require path of a dependency's sibling
  module); naming the module is the workaround and reads better anyway.

## Test surface

- `botopink test` inside `modules/rakun-stylesheet/` (never at the root — the umbrella
  refuses) runs every module's in-file `test {}` blocks, **724/724** on
  commonJS and on erlang: 6 (`spacing.bp`) + 37 (`theme.bp`) + 45
  (`output.bp`) + 602 (`emilia.bp`) + 14 (`preflight.bp`) + 9 (`arbitrary.bp`) + 6 (`container.bp`) + 2 (`compose.bp`) + 3 (`attributes.bp`). The figure below breaks down the 375
  `emilia.bp` carried before fronts 41, 42, 44 and 45; front 41 added 32, front
  42 adds 29, front 44 adds 33 and front 45 adds 41. **Quote the SUM, never the last line** —
  `botopink test` prints one summary PER MODULE, so the figure the run ends on
  is `emilia.bp`'s alone. `emilia.bp`'s 375 are front 56's 33
  (below) plus front 33's 81 plus front 35's 31 plus front 37's 27 plus front
  39's 35 plus front 40's 44 plus front 38's 44 plus front
  34's 50 — two per
  variant family (the `Variant` halves and the CSS the row renders), the three
  dark-mode strategies a cell each, the ranges, a three-deep chain, the indexed
  rows, `Important`, the empty inner list, six walks over the whole table, and
  three end-to-end documents — plus front 36's 30. Three of front 36's 30 are
  that front's REGRESSION: a walk over all **776** `Layout` leaves asserting no
  declaration carries a `rem`, that every one carries a `:`, and that none
  carries a Tailwind class fragment (`inset-x-`, `top-`, `z-50`,
  `overflow-auto`, `float-start`, `box-border`); the same test asserts
  `.Border.Rounded.Lg` DOES carry a `rem`, so the probe is known to
  discriminate rather than to pass vacuously. Three of front 37's 27 are the
  same shape: a walk over all **356** `Flex`/`Grid`/`Gap` leaves (126 + 125 +
  105) asserting no declaration carries a `rem`, that every one carries a `:`,
  and that none carries a Tailwind class fragment (`gap-1`, `basis-`, `order-`,
  `flex-1`, `grid-cols-`, `col-span-`, `auto-cols-`, `grid-flow-`,
  `place-content-`, `items-start`), plus the same `.Border.Rounded.Lg` control
  and a third comparing `Gap`/`Basis` to `Pad` value-for-value rather than to
  literals. A `0.25rem` planted in one `gapScaleAll` arm was confirmed to fail
  the walk.
  Front 39's 35 cover the seven
  keyword sub-sections of `Bg` (with the two-word positions asserted
  individually and again as a space count, and `bg-clip-text` on its own), the
  eight gradient directions, the three stops and their five named colours, the
  palette agreement between `.Gradient.From.Indigo.500` and
  `.Bg.Color.Indigo.500`, the `From` + `Via` + `Stop` composition and the
  reversal that shows token order is load-bearing, the legacy `Bg` leaves
  pinned byte-identical, and three end-to-end documents. Six of the 35 are the
  front's REGRESSION: a walk over all **910** leaves — the 29 keyword leaves,
  the eight directions and the 873 stops — asserting every one declares
  something non-empty carrying a `:`, that none resolves a colour or a length
  (`#`, `oklch(`, `rgb(`, `rem`) and that none emits a Tailwind class fragment.
  Each walk has a CONTROL beside it: the predicates take a declaration STRING
  rather than a token, so `.Bg.White` and `.Border.Rounded.Lg` are shown to
  fail the literal one and four hand-built strings the fragment one, and the
  well-formedness walk is re-run over the SAME list under a predicate known to
  be false for part of it. The well-formedness walk is not boilerplate — a
  shadowed arm falls out of its `case` and declares the EMPTY STRING rather
  than redding, which is the shape front 36's `Break` section was bitten by.
  Front 38's 44 cover the four CORRECTIONS (each asserted against the new
  string AND the absence of the old one), `.Text.Bold` as an explicit
  regression beside the three that changed, the thirteen sizes as `--text-*`
  PAIRS, the nine weights, the five multi-declaration tokens with their exact
  order (`antialiased`, `truncate`, `break-normal`, `line-clamp-N`,
  `line-clamp-none`), tracking and leading with `leading-none`'s literal, the
  decoration family (style, thickness, offset, and the colour asserted to equal
  front 33's `paletteVar` OUTPUT rather than a second literal), lists,
  whitespace, breaking, hyphens, indent against `spacing(8)`, align, tab,
  `content:""` through the codec, `typographyEntries()` and its composition,
  and two end-to-end documents. Six of the 44 are the front's REGRESSION: a
  walk over all **437** leaves (397 `Text` + 34 `Font` + 6 `List`) for
  well-formedness, for a resolved size / colour / font stack, for a raw
  tracking or leading value — `em` cannot be banned outright, because
  `font-stretch:semi-condensed` carries one, so the eleven values are named —
  and for a Tailwind class fragment, plus a planted defect and a 288-way
  distinctness walk over the decoration colour cells. **The class-fragment probe
  is asserted NOT to fire on correct output too**, which is the half that
  usually goes wrong: `var(--tracking-tight)` legitimately contains the string
  `tracking-tight`, and a probe that fires on it is a probe someone deletes.
  Front 44's 33 cover `transition-none` as one declaration against the six
  presets as three, `.Transition.Base`'s eleven-property list asserted WHOLE and
  again as ten `, ` separators, `allow-discrete` in both directions, the two
  nine-step ms ladders compared TO EACH OTHER rather than to a third list of
  literals, the four easings with the keyword and the three references, the
  three PROVISIONAL `--ease-*` entries with the namespace they land in and the
  class that does NOT move when a project overrides one, the four animations as
  a declaration plus a block with the four keyframes bodies pinned as literals
  THROUGH this front's dispatcher, the blockless cases (`None`, `AnimateRaw`, an
  empty-keyframes theme), the dedup of two spinners, the preset-then-override
  ordering both ways round, a three-declaration preset surviving `Hover` and a
  block surviving `Md` unwrapped, and a determinism literal. Four of the 33 are
  the front's REGRESSION over all **36** leaves — well-formedness, no
  `cubic-bezier(`/`infinite`, no class fragment, and the `ms` unit — with a
  fifth holding the controls. **The class-fragment probe is asserted NOT to fire
  on correct output too**, and here that is not a nicety: `var(--animate-spin)`
  contains the class name `animate-spin` and `var(--ease-in-out)` contains
  `ease-in-out`, so both are deliberately absent from the fragment list and both
  are asserted not to trip it. The walk reads DECLARATIONS and not sheets,
  because the `@keyframes bounce` BODY legitimately carries a `cubic-bezier(`.
  Front 45's 41 cover the five positive rotations and the five negative ones
  (upstream's `calc(Ndeg * -1)`), the v4 property asserted against
  the v3 `transform:rotate(` form, the ten scale steps as upstream's three
  `--tw-scale-*` percentages and one reader, the two axes in
  adjacent lines AND the three ladders compared TO EACH OTHER rather than to a
  fourth list of literals, the five translate rows per axis asserted WHOLE with
  the `, 0` fallback, `translate-x-1` against `spacing(1)`'s OUTPUT, the two
  axes proven NOT to compose, the twelve skews on upstream's property with the
  reference file's `skew-x:` asserted absent, the nine origins with the
  hyphenated corner refused, the four `transform-style`/`backface` rows with the
  `transform-3d` → `preserve-3d` trap, the six perspectives as references with
  the prefix read from `nsPrefix(Ns.Perspective)`, the five perspective origins,
  the seven zooms, a scale percentage and `zoom:0.5` asserted in adjacent lines
  with the reason, `§ 16.7`'s two composed rows verbatim plus the assertion that no leaf
  WRITES one of the six variables they read, both `*Raw` variants constructing
  and both wrappers, the five theme entries with the namespace and the class
  that does NOT move under a project override, three compositions and a
  determinism literal. Seven of the 41 are the front's REGRESSION over the 94
  walked leaves — well-formedness, no resolved length, no class fragment, the
  `deg` unit, a 96-way distinctness walk pinning `§ 16.5`'s one legitimate
  collision BY NAME, the `--tw-` namespace absence, and one holding the
  controls. **The class-fragment probe is asserted NOT to fire on correct output
  too**, and here that caught a real defect in the first draft: `var(--tw-scale-x)`
  CONTAINS `scale-x`, `var(--tw-skew-y)` contains `skew-y` and
  `var(--tw-translate-x)` contains `translate-x`, so the bare stems fired on
  `§ 16.7`'s two composed rows; every fragment now carries its numeric or
  keyword suffix. `perspective-*` is absent from the list for front 44's reason
  — `var(--perspective-near)` contains the class name exactly.
  Front 35's 31 cover the scale
  and the nine directions of `Pad` and of `Margin`, `Auto` and `Neg` on each,
  the thirteen `Size` sub-sections (fractions, the per-axis viewport unit, the
  named container and breakpoint widths read back through `themeValue`), the
  `Space` rule shape and its selector, and three end-to-end documents. Three of
  the 31 are the front's REGRESSION: a walk over **1074** `Pad`/`Margin`/`Space`
  leaves asserting the output carries no `rem`, none of `padding-x`,
  `padding-y`, `margin-x`, `margin-y`, and none of `m-0.25`, `m-0.5`, `m-1`,
  `m-2`, `margin-auto`; a fourth walks all **566** `Size` leaves for the same
  `rem`. Front 33's 81: 26 one-per-family `Color` grid tests (all 286
  cells since `1cd39b2` closed the resolver defect) and 26 for
  the `Bg.Color` mirror (all 286), plus `paletteVar`, the shade-survives pin,
  the named colours on both properties, the pre-33 paths, the legacy `Bg`
  leaves, the longhand/shorthand split, the rule shape of a colour token, and
  seven over `paletteEntries()` — its 286 entries, the two anchor values in
  upstream's spelling, white/black not duplicated, composition through
  `extendTheme`, the absence of an `@theme` block in emilia's own output and
  the end-to-end two-token document, and ten over the `Alpha` wrapper — the
  two rows the reference shows, four percentages, two tokens under one
  wrapper, a non-colour token, a keyword colour, both nesting orders with a
  modifier, `alphaWrap` on plain strings, the codec, and the end-to-end
  `bg-red-500/50` document, and three pinning the palette as a
  STRING-TO-STRING mapping with the enum only at its edge — a family and a
  shade that came from no leaf, the property name living in the dispatcher,
  and a project override reaching every rule through the reference. Front
  56's 33:
  - 8 leaf dispatchers (Text.Bold / Text.Size.Lg / Color.Black /
    Bg.White / Layout.Flex / Border.Rounded.Full / Effect.Shadow.Md,
    plus the shape of a section rule) — `Color.Black` reads
    `color:var(--color-black)` since front 33;
  - 5 modifier tests, each naming the row of the variant reference its
    expected selector comes from, plus the theme-driven breakpoint;
  - 2 codec tests walking the dispatcher's own output for a separator;
  - 5 drain tests pinning the commonJS and Erlang host templates
    against each other;
  - 8 public-surface smoke (empty-list class / single-token rule /
    mixed-token fold / hash collapse / a modifier as a sibling rule /
    two-flush independence / the stock render's theme layer and
    keyframes);
  - 5 cascade tests (the conflict rule, list order, call order, an
    unrelated reorder, a variant following the rule it varies).
  The async `flush()` returns `Task<string>` (it cannot fail, so no
  `Result` and a bare `await`); tests `await flush()` via the implicit
  await channel of a `test {…}` block (bot-lang's `test-runner-async` commit).
- `examples/emilia-backgrounds/` is the member `emilia-backgrounds` and is
  front 39's worked example: the seven keyword sub-sections of `Bg` as one rule
  each, the eight gradient directions, a hero panel whose photograph covers its
  box and is anchored to the top so a face is not cropped off, a gradient call
  to action, a three-stop banner whose `Via` is listed after its `From` (so the
  three-colour list is the one that survives), a gradient-text heading built
  from `bg-clip-text` plus a transparent colour, and a texture tiling on one
  axis inside the padding box. Its last two tests carry the front's argument: a
  project's `--color-indigo-500` reaches `.Gradient.From.Indigo.500` and
  `.Bg.Color.Indigo.500` alike — one custom property, not two transcriptions —
  and nothing the example emits carries a `#`, an `oklch(`, a `rem` or a
  Tailwind class fragment. 12 in-file tests, green on commonJS and on erlang;
  it builds and runs.

- `examples/emilia-typography/` is the member `emilia-typography` and is the
  first half of front 38's worked example: the three families as theme
  references with `ui-sans-serif` asserted ABSENT, a size token rendering as
  TWO declarations, the four weights the ladder was missing, `antialiased` as a
  vendor pair and `not-italic` as the value `normal`, `font-stretch`, a price
  table's tabular slashed-zero figures, tracking and leading with
  `leading-none`'s literal `1`, `line-clamp-3` beside the four-declaration
  reset `line-clamp-none`, `truncate` as three declarations from one token, and
  an article header over a clamped excerpt. Its last two tests carry the
  front's argument, asserted from a CONSUMER package: a project that overrides
  `--text-4xl` and `--font-sans` gets the SAME class and the SAME declarations
  — only the theme layer moves — and nothing the example emits resolves a size,
  a leading or a font stack. 11 in-file tests, green on commonJS and on erlang.

- `examples/emilia-text-decoration/` is the member `emilia-text-decoration` and
  is the second half: the four decoration lines on the longhand with
  `{text-decoration:` asserted absent, a line COMPOSING with a style in one
  rule (which the shorthand made impossible), thickness including `from-font`,
  the offset, the palette on `text-decoration-color` with three shades of one
  family giving three distinct classes, lists on three properties, a `pre` code
  block, `break-all` beside `wrap-anywhere` — two properties, which is why they
  are two sections — hyphens on justified text, indent as
  `calc(var(--spacing) * 8)`, a superscript footnote marker, `tab-size`, and
  `content:""` on a `::before` so the two quote characters are shown to survive
  the host cell's codec. It ends with a footnoted paragraph whose links carry a
  wavy sky underline, and with the front's cross-front argument: a decoration
  colour and a text colour are ONE custom property, so a project override moves
  both. 11 in-file tests, green on commonJS and on erlang.

- `examples/emilia-transitions/` is the member `emilia-transitions` and is front
  44's worked example: the six presets with the eleven-property list asserted
  whole and `color,background-color` asserted absent, `allow-discrete` with the
  class's own word asserted absent, a preset then its overrides and the same
  three tokens reversed (two classes, two meanings), the delay ladder with
  `0ms` keeping its unit, the four easings, a project's `--ease-in-out` giving
  the SAME class as the library's with no `cubic-bezier(` anywhere in the
  document, a spinner whose `@keyframes` block is the LAST thing before
  `</style>`, two spinners hoisting one block, the other three built-ins with
  their bodies, `animate-none` and a custom `fade` hoisting none, and a submit
  button whose colours move over 200ms on hover and which dims and grows a
  spinner while the form is in flight. Its last test is the front's argument,
  asserted from a CONSUMER package: nothing it renders resolves a timing
  function or an animation shorthand, and the one `cubic-bezier(` the document
  does carry is inside the `@keyframes bounce` body — front 54's data, not a
  declaration this front emits. 14 in-file tests, green on commonJS and on
  erlang; it builds and runs.

- `examples/emilia-transforms/` is the member `emilia-transforms` and is front
  45's worked example: the five rotations and the five negative ones a `Neg`
  sub-section spells (upstream's `calc(Ndeg * -1)`), the ten scale steps as
  `--tw-scale-*` percentages with the `@property` registration, the two axes
  composing, the five translate rows per axis each writing its `--tw-translate-*`
  and the composition (the `@property` blocks and the `properties` layer in the
  document), a skewed panel on upstream's `--tw-skew-x` and chain with `skew-x:`
  asserted absent, two skews writing both variables, the nine origins with the hyphenated corner refused, a
  flippable card face, the perspective family as references with a project's own
  `--perspective-near` giving the SAME class, the two decimal conventions in one
  test, upstream's `transform-gpu` row, both escape hatches, a
  card that lifts and grows and deepens its shadow on hover, and a chevron that
  flips when its `.group` parent opens. Its last test is the front's argument,
  asserted from a CONSUMER package: nothing it renders resolves a length, and
  the three v4 properties really are three declarations in one rule. 18 in-file
  tests, green on commonJS and on erlang; it builds.

- `examples/emilia-card/` is the member `emilia-card` and depends on `emilia`
  only (decision 114; 1.0.12-beta `06-emilia/33` step 2 dropped its rakun-bpp
  page). It carries 4 in-file tests: the three class names as literals
  (`e_13df5d57`, `e_41222bb0`, `e_bcdc3f6a` — the same bytes on both targets),
  the repeat collapse, the flushed document's utilities layer as one literal
  (the hoisted `Hover` and `Md` rules included), and a second `flush()` holding
  no rule. It is gated like every other example: an example that does not
  build fails the commit, and no list names one allowed to fail (gate-i of
  1.0.11-beta `00-gate`).

- Every `examples/*/` carries a `README.md`: the Tailwind section it mirrors
  (with the upstream pages), the fronts it exercises, its test count and how
  to run it.

- `examples/emilia-modifiers/` is the member `emilia-modifiers` and is front
  34's worked example: a navigation bar that is stacked and dark-surfaced on a
  phone and a row from `md:` up, whose links read the bar's hover through
  `.group`; a form field whose error message is shown by its SIBLING's invalid
  state and nothing else; a table that stripes itself with `Odd`/`Even`/`Nth`
  and pins one declaration with `Important`; and the same panel rendered under
  all three `DarkMode` strategies, which give three different classes because
  the strategy reaches the rule. 16 in-file tests, green on commonJS and on
  erlang; it builds and runs. Two of its assertions pin OTHER fronts' output
  and say so — `Margin.*.__0` is `margin-left:0` rather than a `calc`, and
  `Border.Color.Red.__500` is still `border-color:red` because `Border.Color`
  is pre-front-33 and front 40 owns the rewrite; what this example pins there
  is the selector, which is front 34's.

- `examples/emilia-layout/` is the member `emilia-layout` and is front 36's
  worked example: the eleven display values in one rule, the nine inset
  directions (with the axis pair expanding to two declarations each), the four
  shapes of an inset leaf — fraction, keyword, negative, half step — `overflow`
  as three properties, the two name-versus-value traps (`invisible` →
  `visibility:hidden`, `float-start` → `float:inline-start`) asserted in one
  rule and again as absences, the column ladder reading the theme's containers,
  a media card that clips and isolates with a cropped 16:9 image, and a sticky
  header stacking over a one-axis scroll panel with a badge on a negative
  inset. Two tests carry the front's argument: `.Layout.Inset.T.4` and
  `.Pad.T.4` are compared to each other rather than to two expected strings,
  and halving `--spacing` gives the SAME class with the SAME declarations. 12
  in-file tests, green on commonJS and on erlang; it builds and runs.

- `examples/emilia-grid/` is the member `emilia-grid` and is front 37's worked
  example: the seven direction and wrap rows, the item properties in one rule
  (`flex:1 1 0%` beside `flex-basis:0`, `flex-grow:1`, `flex-shrink:0`,
  `order:-9999`), the NINE alignment property groups in a single rule — which is
  also the proof a grid container reaches every one of them — the
  `flex-start`-versus-`start` asymmetry in one rule and again as an absence,
  templates with their spaces, spans and the thirteenth line, flow and implicit
  tracks, gap on the shorthand and on both axes, and the pre-37 `.Flex.Gap.4`
  compared to `.Gap.All.4` rather than to a string. It ends with the two
  compositions the gap was blocking: a toolbar whose heading takes the remaining
  space and which stacks under `sm`, and a twelve-column dashboard that reflows
  one → six → twelve across `md` and `lg` with a chart panel spanning eight of
  the twelve. Its last two tests are the front's argument: halving `--spacing`
  gives the SAME class with the SAME declarations, and no token in the example
  resolves a length. The two compositions are deliberately outside that walk —
  a BREAKPOINT QUERY reads `--breakpoint-md`, which is a `rem`, and that at-rule
  is front 34's and front 54's, not a declaration this front writes. 13 in-file
  tests, green on commonJS and on erlang; it builds and runs.

- `examples/emilia-spacing/` is the member `emilia-spacing` and is front 35's
  worked example: the multiplier scale through `.Pad.All.*`, the nine padding
  and margin directions, `m-auto` and `mx-auto` on one ladder, a centred
  article shell (`max-w-3xl` + `mx-auto` + `px-6`) as one class and one rule,
  a full-bleed header whose negative `-mx-6` cancels it, fractions, the
  per-axis viewport unit, `size-12`, the six logical forms, and a comment
  thread spaced by `Space.Y` with a reply pulled up by `-mt-2`. Its last two
  tests are the front's argument: no token in the example emits a resolved
  length or a class fragment, and halving `--spacing` gives the SAME class with
  the SAME declarations — only the `:root` block moves. 12 in-file tests, green
  on commonJS and on erlang.

- `examples/emilia-borders/` is the member `emilia-borders` and is the first
  half of front 40's worked example: `.Border.W.{T,R,B,L}` and the two axes in
  one class, the logical `S`/`E` pair asserted to emit NO `border-left-width`,
  the six styles, `.Border.Color.Slate.200` with its shade, the radius ladder,
  side radii (two corner properties) beside corner radii (one), and the
  composition the front exists for — a card rounded across the top, squared
  across the bottom with an explicit `Rounded.B.None`, and a dashed internal
  rule on the bottom edge only. Its two argument tests are asserted from a
  CONSUMER package, which is what catches the cross-package `case` failure
  mode: three shades of one family are THREE classes (they were one, because
  the dispatcher discarded the payload and the class name hashes the body), and
  nothing in the document resolves a colour or a length. 10 in-file tests,
  green on commonJS and on erlang.

- `examples/emilia-outline-ring/` is the member `emilia-outline-ring` and is
  the second half: the four outline properties in one class, a negative offset
  as a `Neg` leaf rather than a sign on a number, and `outline-none` asserted
  BOTH for what it emits and for what it must never emit. The ring half pins
  the custom property beside the composed `box-shadow`, the offset pair, the
  inset flag, and — for contract 4 — a ring and a shadow swapped both ways
  round giving two different classes. The divide half proves the point of a
  `…ToSheet`: the class body is EMPTY (`.cls{` does not appear at all) and the
  width, the colour and the style merge into ONE rule on the children. Its last
  cross-front test repeats front 35's invariant from outside the library —
  `divide-*` and `space-y-*` reach the same children through the same selector.
  13 in-file tests, green on commonJS and on erlang.

- `examples/emilia-cascade/` is the member `emilia-cascade` and is front 56's
  worked example: the reset supplied through `withBase`, the hover hoisted into
  `@media (hover: hover){.e_x:hover{…}}`, the breakpoint hoisted into
  `@media (width >= 48rem)` with its width read from `--breakpoint-md`, the four
  cascade layers in order, `withPrefix`, `withLayers(o, false)`,
  `withImportant(o, true)` and the two-flush contract. 10 in-file tests, green
  on commonJS and on erlang; it builds and runs.

- `examples/emilia-theme/` is the member `emilia-theme` and carries 10 in-file tests over
  the front 54 surface, imported across a package boundary (`from "rakun-stylesheet"`, the
  `{ "workspace": true }` form). It is green on commonJS and on erlang, builds, and runs
  (`botopink run` prints the resolved brand value, the `var(…)` reference form,
  `padding:calc(var(--spacing) * 4)`, the class name, the dark at-rule + selector, and
  the `<style>` document). Since front 56 the flushed document **does** carry the
  theme: `main` renders it with `flushWith(withTheme(defaultOptions(), th))`, and four
  of the ten tests cover the theme layer, the layer order, `withLayers(o, false)` and
  `withPrefix`.

## Spec / phase status

| Phase | Status |
| --- | --- |
| F0 — lib stand-up | DONE-then-undone (V0 surface dropped during V1 WIP) |
| F1 — fill out `Token` | DONE (V1 nested-section landed `3f77623`) |
| F2 — `tokenToCss` exhaustive | DONE for V1 (re-pinned under v0.beta.22 ecosystem-and-snap-tail F2) |
| F3 — modifier composition | DONE for V1 (re-pinned alongside F2) |
| F4 — `flush()` per-render | DONE — async (`Task<string>`); test bodies await via the implicit await channel of a `test` block (bot-lang `<test-runner-async>` commit) |
| F5 — example + docs sweep | DONE — `examples/emilia-card/` migrated to V1 enum-section paths (`.Pad.All.__4`, `.Color.Red.__500`, …) + `await flush()` |
| 1.0.10-beta front 56 — cascade and output | DONE — `output.bp` + the host-cell and public-entry half of `emilia.bp` + `examples/emilia-cascade/`; steps 1–8. `flushSheet` is gone, `drainRules` takes its place, and document assembly happens once in botopink. Fronts 33–47 adapt with `declSheet(…)`, front 34 writes the variant table, fronts 35/40 write `…TokenToSheet`, front 44 writes `blockSheet`, front 55 writes `withBase`, front 59 writes the components layer |
| 1.0.10-beta front 34 — modifiers | DONE — the variant table in `tokens.bp` + `emilia.bp` under the front's banner; 83 modifiers; steps 1-7. One `Variant`-returning fn per name and no wrapping logic: front 56's `nestVariant` applies them |
| 1.0.10-beta front 33 — colour palette | DONE — steps 1–5. `Token.Color` and `Token.Bg.Color` are the 26 x 11 grid + the five named colours; `colorTokenToCss`/`bgColorTokenToCss` emit `var(--color-<family>-<shade>)` through `paletteVar` over front 54's `themeVar`/`nsPrefix`, so no arm discards its shade and no literal ladder is left; `paletteEntries()` carries the 286 OKLCH values from upstream 4.3.2 for a consumer to compose; `Alpha(percent, inner)` is upstream's `/N` suffix. **All 286 cells are reachable since `1cd39b2`**: `.Color.Red.{100,500,700}` and `.Color.Gray.{100,500,700}` were declared and unreachable while the compiler's leading-dot resolver guessed between `Token` and `__Token__Border`, and botopink-lang `f01c508a` closed it; see § Maintainer rules. Fronts 39/40/41/47 consume `paletteVar(family, shade)` and `paletteEntries()` |
| 1.0.10-beta front 35 — spacing and sizing | DONE — steps 1–5: `padTokenToCss`/`marginTokenToCss` emit real CSS properties and every leaf answers front 54's `spacing(n)` (the six `rem` ladders deleted, `padding-x:`/`padding-y:`/`margin-y:` and `m-0.25`/`m-1`/`margin-auto` gone, each pinned); `Pad` and `Margin` carry nine directions over the 35-leaf scale, `Auto` on every margin direction and a `Neg` sub-section on each — 936 leaves, walked by one test. **`Neg.Half` is `{0,1,2,3}`** over front 54's `spacingNegHalf` (it was `{1,2,3}` while `spacingHalf(-0)` could not spell `-0.5`). `Token.Size` carries thirteen sub-sections over `§ 8.1`–`§ 8.7`, 566 leaves, and spells no `rem`: the named container widths are `var(--container-*)` through a `containerVar` over front 54's `nsPrefix`/`themeVar`, `MaxW.Screen.*` is `var(--breakpoint-*)`. `Token.Space` is `space-x-*`/`space-y-*` — the one dispatcher here answering a `Sheet`, under `siblingSelector()`; its child selector and the `--tw-space-*-reverse` names are a PROPOSAL, the local reference carrying no `space-*` row at all. `examples/emilia-spacing/` is the showcase (12 tests). 1640 leaves across the four sections; 202 → 233 inline tests in `modules/rakun-stylesheet`, green on commonJS and erlang |
| 1.0.10-beta front 37 — flexbox, grid and gap | DONE — steps 1–5 + the worked example. `Flex` is the flex container AND the flex item (direction and wrap with the three reverse rows, the `Value` shorthand, `Grow`, `Shrink`, `Basis`, `Order`) plus the WHOLE alignment family of `§ 6.16`–`§ 6.24` — nine property groups, seven of which had no token at all; `Grid` is `§ 6.8`–`§ 6.14` (templates, spans, starts and ends to line 13, flow, implicit tracks); `Gap` is a TOP-LEVEL section because `gap` applies to grid as much as to flex. **356 leaves**, walked by one test, none of which resolves a length: `Flex.Basis` and all of `Gap` answer front 54's `spacing(n)`/`spacingHalf(n)` over front 35's scale, and everything else is a bare integer. `gridRepeat`/`gridFr` spell `repeat(N, minmax(0, 1fr))` and `minmax(0, 1fr)` once each. **The seventh `rem` ladder is deleted** — `flexGapScale` was `__4 -> "1rem"`, the one front 35 left because `Gap` is this front's, and `.Flex.Gap.N` now emits what `.Gap.All.N` emits, asserted side by side; `spacing.bp`'s docblock was corrected with it. **`AlignSelf` and the flat `PlaceContent`/`PlaceItems`/`PlaceSelf`**, not the spec's `.Flex.Self` / `.Flex.Place.Self`: `Self` is a language keyword and neither spelling parses (§ Maintainer rules). The alignment family stays under `Flex` although it applies to grid, because renaming `Items`/`Justify` is what the milestone forbids. `examples/emilia-grid/` is the showcase (13 tests). +27 inline tests in `modules/rakun-stylesheet`, which is **340** on commonJS and on erlang. **Reference gaps left undeclared**: `basis-*` fractions below thirds, and every arbitrary-value form (`grid-cols-[200px_1fr]`, `z-[999]`-style) — the escape-hatch front's. **Reference extents declared by interpolation, confirmed against upstream's compiled output**: `grid-cols-7`…`11`, `col-span-3`…`12`, `col-start-2`…`13`, `order-3`…`12` (functional over any integer upstream; the endpoints asserted byte for byte) |
| 1.0.10-beta front 36 — layout | DONE — steps 1–6 + the worked example. `Layout` is the whole of `§ 5.1`–`§ 5.19` that is not an arbitrary-value form: the eleven display values as the section's own leaves (so `.Layout.Flex` is unchanged) plus fifteen sub-sections — `Position`, `Inset`, `Overflow`, `Overscroll`, `Visibility`, `Z`, `Isolation`, `Float`, `Clear`, `Object`, `Aspect`, `Columns`, `Break`, `Box`, `BoxDecoration` — **776 leaves**, none of which resolves a length. `Inset` carries front 35's nine directions over front 35's scale through front 54's `spacing(n)`/`spacingHalf(n)`, so `.Layout.Inset.T.4` and `.Pad.T.4` agree by construction; the named column widths read front 35's `containerVar`, so `.Layout.Columns.Md` and `.Size.MaxW.Md` are the same reference. `Z` is the one numeric family that is a bare integer. Three name-versus-value traps each have their own assertion (`invisible` → `visibility:hidden`, `float-start` → `float:inline-start`, `aspect-square` → `1 / 1` with spaces). `examples/emilia-layout/` is the showcase (12 tests). +30 inline tests in `modules/rakun-stylesheet`, which is **313** on commonJS and on erlang with front 34 merged in. **`Break` is FLAT** — `BreakAfter`/`BreakBefore`/`BreakInside`, not the spec's `Break { After, Before, Inside }`: a section head named like a top-level payload variant shadows that variant's payload projection, and front 34 carries `After`/`Before` (§ Maintainer rules). **Reference gaps left undeclared**: `columns-4`…`columns-12` (they resolve upstream through the bare-integer rule, not a theme key) and every arbitrary-value form (`aspect-[4/3]`, `z-[999]`) — the escape-hatch front's |
| 1.0.10-beta front 39 — backgrounds | DONE — steps 1–4. Step 1: the seven keyword sub-sections of `Bg` (`Attachment`, `Clip`, `Origin`, `Pos`, `Repeat`, `Size`, `Image.None`), 29 leaves appended after front 33's `Bg.Color` block and the legacy leaves. `Pos` not `Position` (so `.Bg.Pos.*` reads apart from `.Layout.Position.*`), `Repeat.None` not `NoRepeat`, `Clip.Text` the one clip value that is not a `*-box`. The legacy `Bg` leaves are byte-identical and pinned; this front does NOT fold them into `background-color`. Step 2: `Gradient` is a TOP-LEVEL section (a stop sets a custom property, not `background-image`), `Gradient.To` the eight directions — the phrases spelled in one place, `to top right` and never `to top-right`. Steps 3–4: `From` / `Via` / `Stop` each carry front 33's whole grid (291 leaves each) through `paletteVar(family, shade)`, so a stop and a background reference ONE custom property; token ORDER is load-bearing (`Via`'s three-stop list beats `From`'s two-stop one, and `Stop` writes no list so it cannot overwrite `Via`'s). **The stop composition diverges from the spec after the upstream check the spec demanded** — upstream's position variables and `--tw-gradient-via-stops` rest on `@property` registration emilia does not emit, so the registered `#0000` default is written as a `var(…, transparent)` fallback instead. 910 leaves walked for a literal, a length and a class fragment, each walk with a control that fails. `examples/emilia-backgrounds/` is the showcase (12 tests). +35 inline tests in `modules/rakun-stylesheet`, which is **375** on commonJS and on erlang with front 37 merged in. **Reference gaps left undeclared**: colour-stop positions (`from-10%`), radial and conic gradients, gradient interpolation (`bg-linear-to-r/oklch`) and every arbitrary-value form (`bg-[url(…)]`, `bg-size-[…]`) — the escape-hatch front's |
| 1.0.10-beta front 40 — borders, outlines, rings and divides | DONE — steps 1–6 + two worked examples. **1704 leaves** over the whole of `§ 11`. `Border.W` gains the fifth width and eight directional sub-sections (an AXIS is two declarations, a SIDE one, and `S`/`E` are `border-inline-*-width`); `Border.Style` is new; `Border.Color` goes from a two-family stub whose dispatcher DISCARDED THE SHADE (`border-color:red` for every cell) to front 33's full 26 x 11 grid through `paletteVar`; `Border.Rounded` goes from four literal `rem` leaves to a ten-leaf ladder of `var(--radius-*)` on the shorthand and on fourteen directional sub-sections. `Outline`, `Ring` and `Divide` are three new TOP-LEVEL sections — head-audited against the 84 payload variants, the fifteen section heads and the lexer's keyword table before a dispatcher was written, with no collision. **`Outline.Style.None` is the trap**: `outline:2px solid transparent;outline-offset:2px`, asserted BOTH for what it emits and for the `outline-style:none` it must never emit. `ringTokenToSheet` and `divideTokenToSheet` are the two `…ToSheet` dispatchers; `Divide` CALLS front 35's `siblingSelector()`, and the byte-identity test front 35 could not write (because `Divide` did not exist) is now in `emilia.bp` and in `examples/emilia-outline-ring/`. **Upstream VERIFIED while writing**: the divide child selector really is `& > :not(:last-child)`, the zero-then-width pair, the reverse custom properties, `--tw-ring-color`, `--tw-ring-inset`, and the v4 default ring width of **1px** (v3's was 3px), so `--tw-ring-shadow` is `0 0 0 Npx` and NOT the spec's v3-shaped `calc(…)` form. **Still unverified and recorded**: the composed `box-shadow` list, and the whole `ring-offset-*` family, which v4's documentation no longer carries — declared because the spec asks for it, not because it was confirmed. 1704 leaves walked for a literal, a class fragment and well-formedness, each walk with a control that fails, plus a colour-reference walk over all 1440 cells and a 288-way distinctness walk — the literal probe alone does NOT catch a discarded shade, which is this front's own historical defect. Three planted defects were watched redden and removed. **Blast radius outside the front**: `.Border.Rounded.Lg` was fronts 36/37/39's walk CONTROL and is no longer a literal, so all three now use `.Text.Size.Lg`; `examples/emilia-modifiers` pinned `border-color:red` and `examples/emilia-layout` pinned `border-radius:0.5rem`, both updated. `examples/emilia-borders/` (10 tests) and `examples/emilia-outline-ring/` (13 tests) are the showcases. +44 inline tests in `modules/rakun-stylesheet`, which is **419** on commonJS and on erlang. **Reference gaps left undeclared**: `outline-hidden`, and every arbitrary-value form — the escape-hatch front's |
| 1.0.10-beta front 38 — typography | DONE — steps 1–6 + two worked examples. **437 leaves** over the whole of `§ 9` (397 `Text` + 34 `Font` + 6 `List`). `Text` gains five bare leaves (`Overline`, `NoUnderline`, `Start`, `End`, `Truncate`) and seventeen sub-sections; `Font` gains four weights and four sub-sections (Smoothing, Style, Stretch, Nums); `List` is a new TOP-LEVEL section, head-audited against the 84 payload variants before it was written. **Four compiling paths changed what they EMIT**: `.Text.Size.*` is the `var(--text-*)` PAIR with its `--text-*--line-height` where it was a literal `rem` with no leading at all (`§ 9.2`), `.Font.{Sans,Serif,Mono}` reference `var(--font-*)` where they spelled a family stack (`§ 9.1`), and `.Text.Underline`/`.Text.LineThrough` emit `text-decoration-line` where they emitted the `text-decoration` SHORTHAND (`§ 9.17`) — which is what lets a line compose with `Decoration.Style` instead of being overwritten. **`.Text.Bold` is untouched** and has an explicit regression test beside the three that changed. The size change **deleted the library's last resolved `rem`** and with it the walk CONTROL of fronts 36, 37, 39 and 40, all four of which now use a hand-built declaration; three pinned goldens (front 34's button, front 56's leaf and mixed-token flush) and three examples (`emilia-card`, `emilia-backgrounds`, `emilia-modifiers`) moved with it. No leaf resolves a size, a leading, a tracking, a colour or an indent: `Decoration.Color` is front 33's 26 x 11 grid through `paletteVar`, `Indent` is front 54's `spacing(n)`, and `Size`/`Tracking`/`Leading` are front 54's namespaces. `typographyEntries()` contributes nine `--font-weight-*`, six `--tracking-*`, five `--leading-*` and the three family stacks, and deliberately does NOT restate `--text-*` — front 54 already carries it with `§ 21.3`'s values. **PROVISIONAL and marked at the declaration**: the three `--font-*` family values (the reference prints the FORM and no value, so these are emilia's own pre-38 stacks) and `text-indent`'s `calc(var(--spacing) * N)` shape (`§ 9.25` shows `indent-8` as HTML with no CSS). 437 leaves walked for well-formedness, a resolved literal, a raw tracking/leading value and a class fragment, each probe with a control that fails AND — for the class-fragment probe — a control proving it does not fire on correct output. Two planted defects were watched redden and removed. `examples/emilia-typography/` (11 tests) and `examples/emilia-text-decoration/` (11 tests) are the showcases. +44 inline tests in `modules/rakun-stylesheet`, which is **463** on commonJS and on erlang. **Reference gaps left undeclared**: `font-feature-settings`, `list-image-[url(…)]`, `content-['Hello']` — the escape-hatch front's — plus the numeric `leading-3`…`10` ladder and the `8` step on decoration thickness and underline offset, which the 1.0.8 draft declared and `§ 9.11`/`§ 9.20`/`§ 9.21` do not print |
| 1.0.10-beta front 41 — effects | DONE — steps 1–6 + the worked example. **102 leaves** over the whole of `§ 12`. This is the only front so far whose job was mostly to FIX SHIPPED OUTPUT: `shadowToCss` answered `box-shadow:sm`/`md`/`lg`/`xl` — the Tailwind CLASS SUFFIX where a CSS value belongs, which every browser discards — and the single assertion that touched it pinned the wrong string. The four leaf NAMES did not move, so no call site changed; the four values did. `Effect` gains `X2xs`/`Xs`/`X2xl`/`None`/`Inner` beside them, the `InsetShadow` and `TextShadow` sub-sections, and an `Opacity` scale widened from five steps to twenty-one. `Blend` (Mix + Bg, seventeen values each) and `Mask` (nine one-to-one sub-sections) are new TOP-LEVEL sections, head-audited against the 84 payload variants, the seventeen section heads and the lexer's keyword table before a dispatcher was written — **`Blend.Bg` and `Mask.Size` deliberately repeat the names of the top-level SECTIONS `Bg` and `Size`**, which is safe and was run against the real compiler on both targets rather than reasoned about; it is a head beside a top-level PAYLOAD variant that breaks a projection. No leaf resolves a shadow value: the three scales are `themeVar(...)` over front 54's `--shadow-*`, `--inset-shadow-*` and `--text-shadow-*`. **The one exception is `Shadow.Inner`**, which upstream prints as a literal and has no theme entry behind it — the front README's “no `rgb(` anywhere” bullet is wrong about it, and the walk asserts the exception from BOTH sides (every other leaf is `rgb(`-free AND `Inner` does carry one). **PROVISIONAL and marked at the arm that emits it**: six opacity steps (15/35/45/55/65/85), four `mask-position` keywords, four `mask-repeat` keywords, `mask-size:auto`, and the three arbitrary-value wrappers — `§ 12.3` prints fifteen opacity rows, `§ 12.6` twenty mask rows, and the reference prints no arbitrary-value form anywhere. **There is no `Ns.TextShadow`**: front 54's nineteen namespaces do not include `--text-shadow-`, so `textShadowVar` spells the prefix literally and a project's entries land under `--text-` (which does accept them — pinned by a test, with `--inset-shadow-*` as the control). 102 leaves walked for well-formedness, a bare scale step as a value and a class fragment, each probe with a control that fails AND a control proving it does not fire on correct output — `var(--shadow-sm)` CONTAINS `shadow-sm`, so the scale probe anchors on the colon. Three planted defects were watched redden and removed; the first reddened **eleven cells across three fronts**, front 56's smoke test and the new example included. `examples/emilia-effects/` (12 tests) is the showcase. +32 inline tests in `modules/rakun-stylesheet`, which is **495** on commonJS and on erlang. **A residual with front 40, recorded not patched**: front 40's banner says `Ring` composes with `Effect.Shadow` “once it sets `--tw-shadow`” — it does not, because `§ 12.1` prints `box-shadow: var(--shadow-md)` and nothing else, so `[.Ring.W.2, .Effect.Shadow.Md]` is two `box-shadow` declarations and the second wins; closing it needs a reference row, not a patch here. **Reference gaps left undeclared**: `shadow-<color>/<opacity>` — `§ 12.1` gives the class and the prose and NO property/value pair, so front 56's `Rule.declarations` makes the two-step protocol expressible but there is nothing byte-equal to emit |
| 1.0.10-beta front 45 — transforms | DONE — steps 1–6 + the worked example. **96 leaves** over the whole of `§ 16` in one `Transform` section of sixteen sub-sections, plus the two top-level variants `TransformRotateRaw` / `TransformTranslateRaw`. The front rests on a v4 change: `rotate`, `scale` and `translate` are INDEPENDENT PROPERTIES, so three tokens are three declarations in one rule and no `--tw-*` chain is needed — the 1.0.8 draft's `transform:rotate(45deg)` shape is superseded wholesale. No leaf resolves a length: `translate-x-1` is front 54's `spacing(1)` and the five perspective keywords are `--perspective-*` references, with `TranslateX.Px`/`TranslateY.Px`'s `1px` the reference's own literal and the only exception, held out of the walk and asserted from the other side. **THREE ROWS OF `§ 16` TAKE UPSTREAM v4's OUTPUT** (see the front-45 notes above): a skew axis writes `--tw-skew-<axis>` and the five-variable `transform` chain, a translate axis writes `--tw-translate-<axis>` and `translate:var(--tw-translate-x) var(--tw-translate-y)`, each registering its variables as `@property` blocks with `output.bp`'s `properties` layer as the fallback — so both families compose — and `transform-cpu`/`-gpu` are upstream's chain rows. `transformEntries()` contributes the five `--perspective-*`, and **none of its values is provisional** — `§ 16.2` prints each one in parentheses. 94 leaves walked for well-formedness, a resolved length, a class fragment and the `deg` unit, each probe with a control that fails AND a control proving it does not fire on correct output, plus a distinctness walk (101 tokens, 101 distinct declarations since scale took upstream's per-axis variables). Four planted defects were watched redden and removed. `examples/emilia-transforms/` (18 tests) is the showcase. +41 inline tests in `modules/rakun-stylesheet`, which is **569** on commonJS and on erlang. **Declared by interpolation, since confirmed upstream**: nine of ten steps on each of `ScaleX`/`ScaleY`, four of five `Rotate.Neg` magnitudes — and the confirmation moved both families onto upstream's form (`--tw-scale-*` percentages, `calc(Ndeg * -1)`). **Reference gaps left undeclared**: `rotate-x/y/z-*`, `translate-z-*`, `scale-z-*` and a `Translate` both-axes section — `§ 16` enumerates none of them, and the spec's own Definition of Done lists a `Translate` section its Step 3 table does not contain |
| 1.0.10-beta front 42 — filters | DONE — steps 1–4. **108 leaves** over `§ 13` in `Filter` (50) and `BackdropFilter` (58; not `Backdrop`, which is front 34's modifier), plus `FilterRaw`/`BackdropRaw`. Every leaf but `Blur.None` is its `--tw-<family>` property plus one reader of every family with empty fallbacks (`filterChain()`), so filters compose; the spec's `var(--tw-filter)` theme entry is not expressible (`extendTheme` refuses `--tw-`) and would not compose if it were. `DropShadow.None` follows upstream; `filterEntries()` carries the `--blur-*`/`--drop-shadow-*` values. +29 inline tests, **598** on both targets |
| 1.0.10-beta front 43 — tables | DONE — steps 1–4. **21 leaves** over `§ 14` in `Table` plus `TableSpacingRaw`; `border-spacing` is `spacing(n)`, the axes are the one- and two-value forms (no composition). +10 inline tests, **608** on both targets |
| 1.0.10-beta front 46 — interactivity | DONE — steps 1–7. **161 leaves** over `§ 17` in `Interact` plus `InteractAccent`/`InteractCaret`/`InteractScrollbarColor` (payload = `paletteVar`); scroll offsets are `spacing(n)`; `Snap.Type` reads `--tw-scroll-snap-strictness` with `proximity` as its fallback. +25 inline tests, **633** on both targets |
| 1.0.10-beta front 47 — SVG and accessibility | DONE — steps 1–5. **11 leaves** in `Svg` and `A11y` plus `SvgFill`/`SvgStroke`/`SvgStrokeWidthRaw`; `sr-only`/`not-sr-only` are upstream's bodies (read 2026-09-26, `not-sr-only` leaves `border-width`, as upstream). +10 inline tests, **643** on both targets |
| 1.0.10-beta front 55 — preflight | DONE — steps 1–5. `preflight.bp`: eleven `base`-layer rules over `§ 4`'s eight bullets (parity, not byte-equality with upstream), `border-style:solid` beside `border-width:0` as a decision, `preflight()` as a fragment; opt-in through `withBase` only. 17 inline tests, **661** on both targets |
| 1.0.10-beta front 57 — escape hatches | DONE — steps 1–5. Six top-level `Arb*` variants, `arbitrary.bp` with the validating builders, the run-time reject sets re-checked at dispatch, and five comptime validators (their build failures verified against the compiler on 2026-09-26). +8 `emilia.bp` / +9 `arbitrary.bp` tests, **683** on both targets |
| 1.0.10-beta front 58 — container queries | DONE — steps 1–5. `container.bp`, the `Container` markers and three top-level variants; the thirteen widths read from `--container-*`, an undefined one panics; nesting pinned in both orders. +8 `emilia.bp` / +6 `container.bp` tests, **697** on both targets |
| 1.0.10-beta front 59 — custom utilities and variants | DONE — steps 1–5. `compose.bp`: bundles, `compose`, `hocus`/`selector`/`themeMidnight`, and `named()` in `@layer components` with its three refusals; the contract-4 hash re-asserted beside it. `named()` and the read-only `lookupRule` cell live in `emilia.bp` (a sibling cannot import it). 14 tests, **711** on both targets |
| 1.0.10-beta front 48 — attributes | DONE (emilia half) — `attributes.bp` + the slot in `emilia.bp` (`className`/`styled`/`styledWith`/`cls`/`clsWith`, the ASCII gate), the shared fixture (`e_39b87d03` then; `e_f51c2501` since 1.0.12-beta `06-emilia/34` step 5, decision 367), and rakun-bpp's `html_attrs.bp`. The rendered-markup round trip is the rakun-stylesheet bridge's (rakun-bpp front 30). +8 `emilia.bp` / +3 `attributes.bp` tests, **722** on both targets |
| 1.0.10-beta front 54 — theme | DONE — `theme.bp` + `spacing.bp` + `examples/emilia-theme/`; steps 1–7. `spacingNegHalf(n)` is the signed half step (`-0.5` is `spacingNegHalf(0)`; `spacingHalf` refuses a negative whole part), and the unknown-prefix refusal is asserted by its message (`emilia.bp` "front 54 — an entry in no namespace aborts…"). Front 33 hands over `paletteEntries() -> ThemeEntry[]`; fronts 33–47 rewire the dispatchers; front 56 wraps `themeCss`/`keyframeCss`; front 34 consumes `DarkMode` |

The spec is the track README,
[`specs/05-emilia/README.md`](../../specs/1.0.10-beta/05-emilia/README.md), and its
fronts.

## Conformance

The package's reference and cells are the workspace's `conformance/rakun-stylesheet/` (decision 548, root
`AGENTS.md` § Conformance layout): `docs.md` maps the features, each feature directory
(`getting-started/`, `reset/`, `containers/`, `escape-hatches/`, `typography/`, `color/`, `spacing/`,
`sizing/`, `layout/`, `borders/`, `effects/`, `motion/`, `modifiers/`, `theme/`, `output/`) holds its
`docs.md` and its cells, members of the one workspace `conformance/botopink.json` (the targets commonJS, erlang and beam), each
cell declaring rakun-stylesheet as `../../../../modules/rakun-stylesheet`. A feature's `docs.md` links each cell as
`{<cell>/src/main.bp}`, never copying its code. Add a cell with
`botopink cell new conformance/rakun-stylesheet/<feature>/<name>` (from the repository root), a
`botopink.json` naming the cell and its dependency on rakun-stylesheet, the program, `botopink cell check` on it, and accept a candidate
only after reading it, by renaming `*.snap.new` — the tool never writes an accepted `.snap`. A reference
sentence and its cell must agree: when `botopink cell check` answers something the text does not say, the
text is wrong, never the cell edited to match.

Emilia's targets are commonJS and erlang, declared in each cell's `botopink.json`
`"targets"` (decision 475). The `botopink cell check` of today still reads a
`targets` file and runs all four targets, so every cell is red on wasm (and the
`targets` file cannot narrow it: beam accepts the cell and wasm refuses it for
another reason than a host binding) until the cell tool reads the manifest's
`"targets"`. No wasm departure is recorded: a departure never pins a compiler
defect (decision 458). On wasm emilia's `arbitrary.bp` does not build (`join/1`
does not resolve), and a cell with a path dependency prints nothing.
