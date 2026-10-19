# Decision 281 — No code identifier passes as a string.

The example is a small web application in which every code identifier is the thing itself. The
registry is built from `compiler.find(with: [service, restController], member: "make")`: the two
decorators are named by their handles, checked where they are written, so a misspelt `servce`
is an unbound name at build, not an empty catalogue at run time. `main` asks the context for a
bean with `ctx.resolve(GreetingService)` — the type, not `"GreetingService"` — and the answer is a
`?GreetingService` because the argument fixes it. The controller's handler is the method `hello`
the `#[getMapping]` annotates; nothing registers it under its name.

Three strings remain, and each names something outside the program: `"greeting.salutation"` is a
configuration path the `#[value]` field is filled from, `"/api"` and `"/hello/:name"` are URL
patterns, and `"GET"` is the wire spelling `rkDispatch` takes. The program prints `Hello, ana!`
from the bean it resolved by type and `Hello, rui!` from the dispatched request.

Proving cells: `conformance/rakun/web/usage` (the controller, its route patterns and the catalogue
built from the stereotypes) and `conformance/rakun/container/resolve` (the registry from the
catalogue); none of this repository yet resolves a bean by its type value — `Context.resolve` still
takes the type's name in text, which rakun's fronts 04, 08 and 12 (decision 281's steps) replace.

[draft/main.bp](draft/main.bp)
