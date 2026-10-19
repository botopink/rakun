# Decision 206 — `import {…} from "<name>"` resolves only to a package — std, a bundled package or a declared dependency.

A consumer of `rakun` with a module of its own, `greeting`. The program's imports say where each name comes from: `io.terminal.print` from std and `Response` from the dependency `rakun`, both with `from`; `welcome` and `farewell` from the package's own module `greeting`, by their path in braces and with no `from` — `farewell` bound as `bye` with `as`. `greeting` itself imports `Response` from `rakun` the same way. The program prints `200`, `Hello, ana!` and `Bye, ana.`.

Writing `from "greeting"` for the package's own module would be refused at the source string, with the brace form as its fix; a `from "rakun"` keeps meaning the dependency even if the package grew a module named `rakun`.

Cells of this repository that prove it: none yet. `rakun-ssr/project` describes the rule for the generated project (decision 206) without a cell of its own; every rakun cell imports its packages with `from` and std with `from "std"`.

[draft/main.bp](draft/main.bp)

[draft/greeting.bp](draft/greeting.bp)
