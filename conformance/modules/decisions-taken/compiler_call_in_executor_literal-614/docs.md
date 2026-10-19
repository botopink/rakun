# Decision 614 — Both forms are valid: a `compiler.*` call inside an executor is evaluated at build and enters the executor as a literal, exactly as a `val` read before it does — `compiler` exists only at build, so where it runs is never ambiguous; the refusal `syntax-captures-build` goes.

The two decorators register their type in rakun's scan registry with the same executor written two ways. `scanned` calls `compiler.name(decl)!` inside the lambda it hands to `compiler.init`. `scannedByVal` reads the name into a `val` first. The compiler exists only at build, so the call inside the executor is evaluated there and its answer, `"Orders"`, enters the executor as a literal, exactly as the `val`'s `"Invoices"` does. Both compile to one `rkScan("<name>")` statement in the init list, run before `main`, and the program prints `2` and the two names in source order.

What cannot be written is the reverse: a `compiler.*` call whose `comptime` parameter is given a value the executor computes at run time (a lambda parameter, a value made inside it) is refused at that argument, `compiler-arg-at-run-time`, naming the value. A `syntax` parameter takes its argument as written and is never at run time.

Cells in this repository that prove it: none yet. rakun's component markers (`modules/rakun/src/decorators.bp`) write the `val` form today (`val declName = compiler.name(decl)!; compiler.init({ -> rkScan(declName); })`); front 165 s10 lands the cells.

[draft/main.bp](draft/main.bp)
