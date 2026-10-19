# Decision 723 — `use provide(ctx)` takes a context value alone — there is no `(ctx, value)` form; a component that provides another value makes a context of the same type in its body, `val c = comptime createContext(Theme(…));` (a build value) or `val c = use memo({ -> createContext(Theme(…)) });` (run time, memoised with the component), then `use provide(c)`; `use context(ctx)` answers the nearest context of `ctx`'s type provided above, else `ctx`'s own default.

`draft/theme.bp` declares the `Theme` type and its context value `themeContext`, with a `light` default. `Card` imports that value and reads it with `use context(themeContext)`. The handle supplies two things: the type to match a provider by, and the default to fall back on. No catalogue is searched.

Each page that wants another theme makes a context of the same type in its own body and provides it with `use provide(…)`, the one form the hook takes. `DarkPage` makes its context at build (`comptime createContext(Theme(cls: "dark"))`). `BrandPage` makes its context at run time from a prop, inside `use memo({ -> … })`, so it is computed on the instance's first render and kept. `Reset` provides `themeContext` itself, which puts the declared default back below it. The program prints one line of HTML whose four cards carry the classes `light`, `dark`, `brand-rakun` and `light`.

There is no `use provide(themeContext, Theme(…))`: a context value is the whole argument, and a value to provide is a context made in the body. The match is by type, so two contexts over one base type are two types, and a `Card` under a provider of another type still reads its default.

Cells in this repository that prove it: none yet. `rakun-bpp`'s render already provides its root sheet with `use provide(createContext(renderSheet()))` (`modules/rakun-bpp/src/render.bp`), but no cell reads a context through an imported value. That read and std's `memo` arrive with 144 B-17 and front 165 s10.

[draft/main.bp](draft/main.bp)
[draft/theme.bp](draft/theme.bp)
