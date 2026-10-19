# Decision 337 — The shorthand import goes; `mod m;` binds the namespace `m` in the module that declares it.

The program answers a greeting the way a rakun handler does. `draft/routes.bp` is a module of the package: it declares `greet` as `pub` and builds its reply with rakun's `Response.ok`, imported `from "rakun"` by the library module's path (`http.Response`). `main` reaches `greet` by the module's path with no `from` — `import {routes.greet};` for the item, `import {routes};` for the namespace, so `routes.greet("bia")` reads through it. Every name of another package names its source: `Response` from `"rakun"`, `io.terminal` from `"std"`. The program prints `200 Hello, ana!` and `Hello, bia!`.

The refused spelling is the shorthand. `import {greet};` has no `from` and its first segment names no module of the package: it is `shorthand-import` at the item, and since only `routes` declares `greet` `pub`, the error writes the fix, `write import {routes.greet};`. A bare `import {Response};` does not reach rakun either, though rakun declares the name: no bare name reaches a dependency's or std's modules.

337 (2)'s `mod m;` namespace and (3)'s no-combined-form are replaced by decision 592 (1): every `.bp` under `src/` is a module, its path its name, and there is no `mod` / `pub mod` — `routes` needs no declaration to be imported. rakun's own `root.bp` files still declare `pub mod …` today; they go with 592's migration over every repository.

Cells in this repository that prove it: none yet. rakun's modules already import each other by path (`import {runtime.rkSingleton};` in `modules/rakun/src/rakun.bp`); the feature cells come with front 150's Conformance step (decision 465).

[draft/main.bp](draft/main.bp)
[draft/routes.bp](draft/routes.bp)
