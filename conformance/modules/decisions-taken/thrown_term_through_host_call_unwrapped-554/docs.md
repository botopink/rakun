# Decision 554 — A library sidecar that unwinds with a thrown term through a `host`-wrapped call is a library gap, never a compiler mechanism

The example is the shape rakun-app's navigation takes instead of an unwinding term. `Post` is a
server component that cannot render its post: rather than raising a navigation signal through a
host-wrapped call and counting on something above to catch the thrown term, it answers the
navigation as data — `Rendered.Redirect(to: "/login")` or `Rendered.NotFound` — beside the
`Rendered.Page(…)` it answers when it can render. The renderer, `serve`, reads that value with a
`case` and turns each into its response: a `303` with `Location`, a `404`, or the page.

The same goes for a problem: `loadPost` answers `Result<string, Problem>`, and the component
handles the `Error` on the spot. Nothing in the program throws a term across `loadPost`'s host
binding (`#[compiler.external(…, result: true)]` converts a host raise into an `Error` at that one
boundary), and no mechanism lets one through: no wrapper exempting a binding, no catcher parsing
the host's text. `main` serves three paths and prints each status.

Proving cells: none in this repository; rakun's tests that unwind a navigation signal or a
`rakun_problem` through a wrapped binding stay red as library gaps until rakun front 150 / 165 make
navigation and problems data.

[draft/main.bp](draft/main.bp)
