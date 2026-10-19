# Decision 425 — A template call expands wherever an expression may stand.

The example puts template calls in every position an expression may stand, and each expands as it
would in a `fn` body. `html @`…`` is the method body of `Menu.render`, the default of `Slot`'s
field `fallback`, the body of the lambda `items.map({ i -> html @`<li>${i}</li>` })`, an argument
to `renderToString`, and the result of a `case` arm in `badge`. `stats @`…`` — a template written
here that answers a tuple — is a destructuring initializer: `val #(n, total) = stats @`3,12``
binds `n` to 3 and `total` to 12.

Each call is expanded at build; `main` prints what each produced. Had any of them been left
unexpanded, that would be a compiler error at the call — never an `undefined` or an unbound name
discovered when the program runs.

Proving cells: `conformance/rakun-bpp/html-dsl/html_dsl_hole` expands `html` in a module-level
`val`; the other positions have no cell in this repository yet. They come with `01-checker` step 29
and `04-rakun/137` step 2.

[draft/main.bp](draft/main.bp)
