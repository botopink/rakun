# Decision 381 — The `styledProperty "…"` literal answers the record `StyledProperty` — declarations as a value, never a `@Component`.

`padAll` is a family. It answers the record `StyledProperty`, declarations as a value, so building one reads no context and registers nothing. The function is `Any`, and `padAll(2)` is computed at build. `tab4` is a property held in a `pub val`, a value of build too. Neither has a class of its own: a property only enters a stylesheet when it is inlined into a `styled`, as `${padAll(2)}` and `${tab4}` are inlined in `codeBlock`'s `.block` rule, which is Tailwind's `@apply`. `main` reads the records' declarations and prints `tab-size: 4;` and `padding: calc(var(--spacing) * 2);`. The `#[theme]` `appTheme` is there because an application that expands a `styled` literal declares exactly one theme.

A `StyledProperty` used alone, `use tab4` in a component or `#[styled(tab4)]` on a tag, is refused at the use with the fix `a property has no class — put it in a styled`. `StyledPropertyView` is gone: a property is never a `Component`.

Cells in this repository that prove it: none yet. `styledProperty` still answers `StyledPropertyView` in `rakun-style`; the record arrives with front 150 s32.

[draft/main.bp](draft/main.bp)
