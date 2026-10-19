# Decision 354 — A component is `@Component<R>`; what a body reads from above it is a context, provided by a hook — React's context in botopink's spelling.

The example renders a page through `rakun-bpp` and shows the one wrapper doing both jobs. `Badge` and `DarkPanel` answer `Component<Element>`; `Element` implements `Renderable`, so each is written as a tag in the markup (`<Badge label="outside" />`). `themeClass` answers `Component<string>`; `string` is not renderable, so it is a hook and `Badge` reads it with `use themeClass()`. Nothing else marks the difference: there is no `@Hook`, no base parameter and no `@Context<C>`.

`themeContext` declares the context with its default, a light `Theme`, under `comptime createContext(…)`. `DarkPanel` makes a dark context of the same type in its body and provides it with `use provide(dark)`. The value reaches what `DarkPanel` renders below it, the inner `Badge`, which prints `dark:bg-black`. `DarkPanel`'s own read (`data-own`) still sees `light`, and so does the `Badge` beside it, because it has no provider above it and reads the declared default. The page renders from `RenderScope.root()` through `renderComponent`, and the program prints the page's HTML as one line. A component's view type may also be written `View`, `rakun-bpp`'s alias for `Component<Element>`.

The read is written as decisions 722 and 723 spell it: `use context(themeContext)` passes the context value the reader imports, never a bare type. `Theme` is plain data, so the island rule (6) has nothing to carry here. `rakun-bpp`'s render provides `StyledContext` at its root, and rakun's pipeline provides `RequestContext` (7). The lowering (8) is decision 388's, shown in its own cell.

Cells in this repository that prove it: `rakun/request-context/request_context` (the request scope read through a hook over a `Renderable`), `rakun-bpp/hooks/hook_noun_custom` (a `Component<T>` read with `use`) and `rakun-bpp/components/render_nested`. The context read through an imported value arrives with 144 B-17 and front 165 s10.

[draft/main.bp](draft/main.bp)
