# theme-module

### A theme is a module

Upstream shares a theme between projects by importing a CSS file. In botopink a
theme is a **function in a module**, so sharing one is an ordinary package
dependency: a package exports `brandTheme() -> Theme` or a bare
`entries() -> ThemeEntry[]`, and the consumer composes it with `extendTheme`.
[`examples/emilia-theme/`](../../../examples/emilia-theme/) is the worked example.
