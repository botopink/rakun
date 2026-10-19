# Decision 613 — (d), the rule behind 581 (2): what flows from build into an executor is always admitted — a `comptime` value as a literal, an `syntax` as the code it is, a run-time value as itself — and only the reverse is impossible (611); so `decl` inside an executor is the annotated declaration itself, spliced as code and bound to that declaration, on every kind, and the checker applies its ordinary rules to it, typed by the `syntax decl` parameter's declared type (716).

The example has two decorators whose executors use `decl`. `#[warm]` on rakun's `Users` service
writes `decl.make()` in its executor; `decl` there is `Users` itself, spliced as code, so the call
is `Users.make()` — the factory `#[service]` added. It is typed by the parameter's declared type,
the behavior `Made`, so a type with no `make()` would be refused at the annotation. The module also
declares a function named `make`; it is never the one called, because the splice names the
annotated declaration, not whatever its name resolves to in the module. `#[onBoot]` on the function
`seed` writes `decl()`: on a function, `decl` is the function value.

Values flow one way. The decorator reads `compiler.name(decl)` at build and the executor uses the
result as a literal, which is always admitted; a value computed at run time could never reach the
decorator's body. Both executors run before `main`, in source order, so `main` prints `Users,seed 3
module make`. Writing `register(decl)` where a value is expected, on a type, is the checker's
ordinary `` `Users` is a type, not a value `` at the annotation.

Proving cells: `conformance/rakun/plug-and-play/boot_modules` (`#[rakun.module]`'s executor
registers the annotated function itself, `make: decl`); the typed handle on a type is 165 s10's
registrations (`decl.make()`, `decl.Tx.make()`), which bring their cells.

[draft/main.bp](draft/main.bp)
