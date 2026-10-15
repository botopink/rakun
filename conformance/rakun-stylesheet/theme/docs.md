# The theme

> Package: [`rakun-stylesheet`](../docs.md) · index: [`../../docs.md`](../../docs.md)

A theme is a **flat list of CSS custom properties**, not nineteen record
fields. That is what CSS itself has, and it is the only shape in which
"clear one namespace" and "clear everything" are ordinary values rather than
nineteen more functions.

{theme-api/src/main.bp}

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
| `defaultTheme() -> Theme` | rakun-stylesheet's stock theme |
| `emptyTheme() -> Theme` | a theme with nothing in it — the `--*: initial` reset |
| `extendTheme(th, entries) -> Theme` | add entries; a name already present is **overridden in place** |
| `clearNamespace(th, ns) -> Theme` | drop one namespace — the `--color-*: initial` reset |
| `namespace(th, ns) -> ThemeEntry[]` | the entries of one namespace, in the theme's order |
| `themeValue(th, name) -> string` | the literal value, or `""` when the theme does not carry the name |
| `themeVar(name) -> string` | the reference form, `var(--name)` — what a utility emits |

`--spacing` is a **single variable**, so `nsPrefix(Ns.Spacing)` is `--spacing`
with no trailing dash.

{theme-brand/src/main.bp}

## The name is `extendTheme`, not `extend`

`extend` is a **language keyword** (`Name extend Type { … }`, the type-extension
block), so `fn extend(…)` does not parse. Every front that composes a theme
writes `extendTheme`.

## `extendTheme` refuses an unknown namespace

An entry whose name starts with none of the nineteen prefixes is **refused**,
loudly, naming the offending name. There is no permissive mode and no argument
that relaxes it: an unknown prefix is a typo or a namespace this library does
not have, and both are errors. A variable that is silently absent is debugged as
a cascade bug days later, in a browser.

{theme-unknown-namespace/src/main.bp}

## Spacing — `spacing(n)`

| Function | What it answers |
| --- | --- |
| `spacing(n) -> string` | `calc(var(--spacing) * n)`; `spacing(0)` is `0` |
| `spacingHalf(n) -> string` | `calc(var(--spacing) * n.5)`; `n` is never negative (a negative `n` aborts) |
| `spacingNegHalf(n) -> string` | `calc(var(--spacing) * -n.5)`; `spacingNegHalf(0)` is the `-0.5` rung |

rakun-stylesheet **never resolves a spacing value**. Every spacing utility is a multiplier
of `var(--spacing)`, resolved by the browser, so the same token list renders
differently under a theme whose `--spacing` is `4px` and one whose `--spacing`
is `0.25rem`. Emitting `1rem` instead would make that override silently
ineffective.

{spacing-functions/src/main.bp}

A negative whole step needs no second function (`spacing(-4)`). A negative HALF
step does: `spacingHalf` takes the whole part as an `i32`, and an `i32` has no
negative zero, so `-0.5` could not be spelled through it — the sign lives in
`spacingNegHalf`'s name instead. `spacing` takes an `i32`, not an `f64`, so the
emitted string never depends on a backend's float formatting; the fractional
steps are a closed set that the two half functions cover exactly.

## Rendering a theme

| Function | What it answers |
| --- | --- |
| `themeCss(th) -> string` | the `:root` body — `name:value` joined with `;` |
| `keyframeCss(th) -> ThemeEntry[]` | the `@keyframes` bodies, which cannot sit inside `:root` |
| `darkAtRule(th) -> string` | the at-rule a dark rule nests inside, or `""` |
| `darkSelector(th) -> string` | the selector a dark rule is written against |
| `withDarkMode(th, mode) -> Theme` | swap the strategy, change nothing else |

The block is **always the whole theme**. Upstream emits only the variables a
build used, and `@theme static` emits all of them; rakun-stylesheet's behaviour is the
second, because tree-shaking would need a whole-program pass over every
`emilia()` call site and rakun-stylesheet hashes per call site.

Entry order is the theme's own, and it matters: rakun-stylesheet's class names are content
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

## The colour palette

`defaultTheme()` carries `--color-black` and `--color-white` and nothing else.
The 286 numeric values are front 33's data, handed over as
`paletteEntries() -> ThemeEntry[]` and composed by the consumer:

{palette-entries/src/main.bp}

It is a **list, not a rendered block**, and that is the point: a project that
already imports upstream's own theme leaves it out and still uses every colour
token, because a token emits `var(--color-red-500)` and whoever declares that
variable is the consumer's call. `emilia(...)` emits no `@theme` block of its
own, at any size of token list.

The values are transcribed from upstream `tailwindcss` **4.3.2**'s
`theme.css`. The reference prints exactly two of them
(`--color-red-500`, `--color-blue-500`) in the decimal-lightness spelling
`oklch(0.637 0.237 25.331)`; upstream writes the same colour as
`oklch(63.7% 0.237 25.331)`. Both are the same lightness in OKLCH; rakun-stylesheet
takes upstream's, so the emitted `@theme` block is byte-equal with the one a
project would otherwise import.

## A theme is a module

Upstream shares a theme between projects by importing a CSS file. In botopink a
theme is a **function in a module**, so sharing one is an ordinary package
dependency: a package exports `brandTheme() -> Theme` or a bare
`entries() -> ThemeEntry[]`, and the consumer composes it with `extendTheme`.
[`examples/emilia-theme/`](../../../examples/rakun-stylesheet/emilia-theme/) is the worked example.

{theme-module/src/main.bp}
