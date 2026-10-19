# Decision 368 — `styled`'s reader keeps source order, and emilia's `flush()` keeps the document frame around `styled`'s sheet.

An application of `rakun-style` and `rakun-stylesheet`. `focusPad` writes a background, then a `&:focus` block, then a padding: `rakun-style`'s reader keeps that order, so the padding opens a second rule of the class after the nested one. `Render` registers both values with `use` below a provider that keeps nothing; the first line printed is `.k{background:#ffffff}.k:focus{background:var(--color-gray-100)}.k{padding:calc(var(--spacing) * 4)}` with `k` the class, not one rule with both declarations before the focus rule. `padFocus` holds the same declarations with the padding first: another order, another class, so the second line, `false`, says the two class names differ.

`rakun-stylesheet`'s `flush()` writes the document frame around the layered sheet — the `@layer theme, base, components, utilities;` statement, the theme's `:root{…}`, the base rules, then the `@layer` blocks; the program prints whether the frame's statement comes before the theme's `:root`.

Departure on `feat`: `use focusPad` of a component is refused with `use-of-non-context-fn`.

Cells of this repository that prove it: none yet. `examples/rakun-style/styled-source-order` and `modules/rakun-style/test/source_order_test.bp` run the reader's half; the frame around `styled`'s sheet comes with `06-emilia/34` step 5.

[draft/main.bp](draft/main.bp)
