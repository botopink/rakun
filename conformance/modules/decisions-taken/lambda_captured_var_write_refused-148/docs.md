# Decision 148 — A lambda's write to a captured `var` is refused at check time on every target, located at the write, unless the lambda i

The example is the refused program. It counts rakun `Response`s two ways. The first count is legal: the `for (responses) { r -> … }` body is a `forEach` body, so its write to the captured `served` is allowed. The second is not: the lambda handed to `responses.map` writes the captured `missing`, and the checker refuses the program there, located at `missing = missing + 1`, on every target — a `map` callback may run anywhere and any number of times, so the write would mean something different on each backend.

A local closure called at statement position may write a captured `var` too; a counter that must outlive one call is a module-level `var`.

Cells of this repository that prove it: none yet. rakun's sources count inside `for` bodies only (`modules/rakun-style/src/theme.bp`, `themeValue`); the refusal is the compiler's.

[draft/main.bp](draft/main.bp)
