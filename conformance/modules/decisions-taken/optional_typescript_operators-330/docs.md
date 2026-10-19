# Decision 330 — `?T` is read with TypeScript's operators and has no methods; `result` goes; a type declared in a type is its associated type.

The example routes paths to rakun modules. Every optional in it is read with an operator, never with a method.

- `routes[0]?.match("/api/users")` is a `?Route.Match`. `hit?.module ?? "none"` and `hit?.rest ?? ""` read it, and the line prints `web users`.
- `self.guard?.(path) ?? true` calls the guard when the route has one. A route with no guard passes. The admin route's guard refuses a path with `..`, so `routes[1]?.match("/admin/../etc")?.module ?? "refused"` prints `refused`.
- `docs?.[0]?.origin` indexes through an optional list. The index already answers `?Doc`, and `?.` keeps it a `?Doc`, never a `??Doc`. The line prints `inline.json`.
- `rakun.registry.find("web")!.name` asserts that the module is registered and prints `web`. If the module were missing, the `!` would abort with the expression and its location, the same on every target. `find("mail")?.name ?? …` prints the default.

Reading a `Result` is a separate matter. `parseJson(…).unwrapOr([])`, `started.isError()` and `rakun.start("admin").isOk()` are the `Result`'s own methods, and there is no `result` namespace to call. `rakun.start("billing")` names no module, so the last line prints `true true`.

`Route.Match` is declared in the body of `Route`, which makes it `Route`'s associated type: `match` answers `?Route.Match`, named through its owner.

Several spellings are refused. An operator over a value that is never `null` is a compile error: `?.` on `routes.length`, or a `??` whose left side cannot be `null`. So is `??` beside `&&` or `||` without parentheses. A `?T` has no `map`, `flatMap` or `unwrapOr`.

Cells in this repository that prove it: none yet. rakun's cells use `??` and `?.` incidentally (`rakun/auto-configuration/autoconfig`, `rakun-bpp/components/counter_ssr`), and the cells for the rule come with front 165 s7, the workspace's Conformance step.

[draft/main.bp](draft/main.bp)
