# Decision 379 — A context is named by its value's type: `createContext(value)` declares or makes one, `use provide(ctx)` takes the context alone, `use context(T)` reads by type

The example names three contexts by their value's types. `themeContext` declares, at module level
and at build (`comptime createContext(…)`), the default of `Theme`; `idiomaContext` and
`moedaContext` declare `Idioma` and `Moeda`, two types over the same shape (`code: string`), which
are therefore two contexts — providing an `Idioma` never answers a read of `Moeda`.

`Page` provides two values below it. The theme it builds at build time is a context value made
with `comptime createContext(Theme(…))`; the language it makes at run time from the request's
`Accept-Language` is memoised with the component, `use memo({ -> createContext(Idioma(…)) })`.
Each is handed to `use provide(c)` alone. `Price` reads through the handles it imports:
`use context(themeContext)` answers the nearest `Theme` provided above (the page's dark one), and
`use context(moedaContext)` finds no `Moeda` provided and answers the declared default, `BRL`.
`main` renders `Page` and then `Price` alone, where every read falls back to its default.

A second `createContext(Theme(…))` at module level anywhere in the program would be refused, naming
both lines: one declaration per type.

Proving cells: none in this repository yet; rakun-bpp's render tests use contexts, but no cell under
`conformance/` does. They come with `01-compiler/134` step 6, `01-checker` step 36 and `08-bpp/119`.

[draft/main.bp](draft/main.bp)
