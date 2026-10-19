# Decision 388 — A `@Component<R>` at run time is a lambda over an opaque `RenderScope`; calling a component only makes the lambda, and the render library decides who runs it, when, and with which scope.

`Card(items[0]!)` runs nothing. It answers the lambda `Card` lowers to, so `lone` is a value and no `use` has been read yet. `items.map(Card)` likewise answers two lambdas, and `count`, a generic function that knows nothing of components, takes them like any list. The program runs a component in one of two ways. Outside every body, `lone.run(RenderScope.root())` hands it a root scope and answers its tree and the scope its body's `provide`s made for its children; the first line is `<li>tea (en)</li>`, the default locale, because no provider is above it. Inside `rakun-bpp`'s renderer, `renderComponent` holds the scopes: it runs `List` with the root scope and each `Card` with the children's scope `List` answered.

`List` provides a locale made in its body. The two renders in `main`, `pt-BR` and `fr`, each start from their own `RenderScope.root()`, so each card reads its own list's locale, and the two lines end in `(pt-BR)` and `(fr)` for both cards. The scope travels as an argument, never through a current-context stack, a process dictionary or `AsyncLocalStorage`, so nothing is shared between two renders on any target.

`{cards}` puts the list of component values in the markup, and `rakun-bpp`'s renderer runs them while it descends.

Cells in this repository that prove it: `rakun-bpp/error-boundaries/error_boundary` (a boundary is a node holding a component value, run with the scope it was met with), `rakun/plug-and-play/boot_modules` (a module runs as a component over a scope without a DOM) and `rakun-bpp/streaming/suspense_boundary`.

[draft/main.bp](draft/main.bp)
