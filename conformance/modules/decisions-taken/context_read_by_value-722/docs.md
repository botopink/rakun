# Decision 722 — A context is read through a context value the reader imports — `use context(themeContext)`, never a bare type name — answering the nearest context of that type provided above, else the default the handle carries; the handle is imported as any name, so the default is found through the import graph and nothing is searched

The example keeps the context's declaration in its own module, `theme.bp`, and reads it from
another. `theme.bp` declares `Theme` and `pub val themeContext = comptime createContext(Theme(…))`
— the handle and the default it carries. `main.bp` imports `themeContext` as it imports any name
and writes `use context(themeContext)` inside `Card`, a `component fn`: `t` is a `Theme`, typed by
the handle, and the read never names the bare type `Theme`.

`Page` provides another value of the same type below it — a context it makes in its body,
`comptime createContext(Theme(primary: "#111", …))`, handed to `use provide(dark)` — so the first
`Card` reads the dark theme: the provider is matched by the context's type. The `Card` rendered
alone in `main` has nothing provided above it and answers the default the imported handle carries.
No module is searched for that default and no catalogue of contexts is built: the import is how the
reader reaches the declaration.

Proving cells: none in this repository yet; the 30 `use context(<Type>)` sites in rakun are
rewritten by B-17's step 6 and 165 s10, which bring the cells.

[draft/main.bp](draft/main.bp)

[draft/theme.bp](draft/theme.bp)
