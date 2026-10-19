# Decision 625 — (b) for the computed member, and the rule behind it: code never enters the compiler as a string — it is written (a `syntax` parameter, a template text) or built as the typed AST; `compiler.build(text)` is removed and `compiler.ast(node) -> anyvalue` takes its place.

Two ways code reaches the compiler in a rakun program, and neither is a string. The route marker `get` takes the annotated function as `syntax decl` and registers it with `compiler.init`: the executor hands `decl` itself — the function as code — to rakun's `rkRegisterRoute`, so nothing is generated as text and the run-time registry is what holds the route. `rkDispatch("GET", "/hello")` then answers the handler's body. The template `mail` answers a constructor call built as the typed AST: a `Call` whose callee is the `Name` `Mail` and whose two labelled `Arg`s carry `Lit` values read from the template text, handed to `compiler.ast` and typed where `mail @`…`` stands — here as the `Mail` the `val` is annotated with. The program prints the route's answer, then `ana@example.com Welcome`.

`compiler.build(text)` is gone: a decorator or a template that wrote its output as source text for the compiler to parse back would be code nobody wrote, its errors located in text no file holds. rakun's markers that still compute members as text (`rkRoutes`, `rkBeans`, `rkHooks`, …) are the ones this decision retires.

Cells of this repository that prove it: none yet — rakun's markers move to `compiler.init` registrations and its generators to `compiler.ast` in front 165 s10 / s11, after 144 B-149.

[draft/main.bp](draft/main.bp)
