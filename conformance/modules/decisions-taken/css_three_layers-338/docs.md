# Decision 338 — CSS is built in three layers — `css`, `styled`, emilia — none of which knows `.bpp`; jhonstart integrates them, and a `.bpp` file's style is a section of its own.

The example uses the three layers through the packages of this repository that hold them. The base,
`css`, is the library rakun-style depends on: it reads and renders a stylesheet and scopes it, and
the program never names it. rakun-style (was `styled`) is the second layer: `card` is a component
built from a `` styled @`…` `` literal whose `@variant md` and `--theme(--breakpoint-md)` read the
application's one `#[theme]`, `appTheme`, where `md` is `52rem`; `padAll` is a `styledProperty`, a
record of declarations with its value in a `${…}` hole, the shape a rakun-stylesheet family has; and
`onHover` wraps it in a `styled` variant, the property's declarations inlined with no class of its
own. rakun-stylesheet (was `emilia`) is the third: its tokens reach the `<h1>` as the tag annotation
`#[emilia(…)]`, computed at build. None of the three knows `.bpp` or the markup: rakun-bpp (was
`jhonstart`) is what writes `page` with `` html @`…` `` and merges the emilia class into the tag's
`class`. The sheet holds the card in `components` and the hover rule in `utilities`, whose classes
keep emilia's `e_` prefix. A `@utility` or `@theme` in a literal is refused: a `val` or a function
names a component, and the theme is the `#[theme]` value.

Proving cells: `conformance/rakun-stylesheet/getting-started/quickstart` and
`conformance/rakun-stylesheet/theme/theme-module` show the third layer in today's run-time spelling;
the first two layers have no cells in this repository yet (front 119, `06-emilia/34`).

[draft/main.bp](draft/main.bp)
