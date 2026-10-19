# Decision 352 — A `styled` value registers in the render's sheet through the root context `StyledContext` (354), where it is used — `use x`, `#[styled(x)]` —, never where it is made (377).

An application of `rakun-style` whose page provides the render's sheet. `badge` makes a `styled` value with a value hole, so it is computed at render; making it reads no context and writes nothing — `main` makes `badge("green")` outside every provider and never uses it. `Card` makes one with `badge(c)` and registers it on the next line with `use look`: the use reads the root context `StyledContext` (`rakun-style`'s `styledContext`) at that point, below `Page`'s `provide`, and hands its class and rules to the sheet's writer, which prints one `registered components …` line per use. The `${padAll(2)}` splice inside `badge` inlines the `StyledProperty`'s declarations and registers nothing of its own. `Page` is the render's root and the one that provides `StyledContext`: the sheet is that render's record, not a store kept by `rakun-style`.

Used with no provider above it, the same `use` reads the context's declared default, whose writer aborts naming the missing provider; a literal computed at build writes to the build's sheet instead of a render's.

Departure on `feat`: `use look` of a component is refused with `use-of-non-context-fn`.
Departure on `feat`: `rakun-style` still exports `StyledView` / `StyledPropertyView` and `styledProperty` answers `Component<StyledProperty>`, not the record `StyledProperty` (661).

Cells of this repository that prove it: none yet. `examples/rakun-style/styled-context` and `styled-context-unbound`, and `modules/rakun-bpp/test/styled_sheet_test.bp`, run the same mechanism; the cells come with front 119 steps 2 and 5 and `06-emilia/34` step 5.

[draft/main.bp](draft/main.bp)
