# Decision 266 — A `comptime` is evaluated at compile time everywhere, calls and records included

The program builds four values at build and uses them when it runs. `ports` is a call, `Dict.ofEntries` over two calls of the program's own `portOf`; the compiler runs all three and the emitted program holds the dictionary they built, so `ports.at("web")` reads `8080` with no call of `portOf` left at run time. `services` is an array of rakun's `Service` records, emitted as their construction. `delay` is a `comptime { … }` block: its `val` and its subtraction run at build and its `break` value, rakun's `Lifecycle.Lazy(afterMs: 1010)`, is what the module holds. `describe` is a reference to the top-level function `label`, emitted as that reference, so `services.map(describe)` calls `label` at run time. Inside `main`, `comptime Dict.empty()` builds the empty dictionary the same way it would at module level. The program prints `8080`, `service web, service admin`, `lazy 1010` and `0`, alike on every target the cell runs on.

What cannot be lifted is refused where it is written: a `comptime` whose value is a lambda capturing state, or a resource such as an open connection or file, is `comptime-value-not-liftable`.

Cells in this repository that prove it: none yet. rakun's own entry-point catalogue (`modules/rakun/src/context.bp`, a `comptime` block over the stereotyped types) is the library's use of the rule; its cells come with front 165 s5.

[draft/main.bp](draft/main.bp)
