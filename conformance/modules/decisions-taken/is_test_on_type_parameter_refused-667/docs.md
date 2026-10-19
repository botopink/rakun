# Decision 667 — `v is T` with `T` a type parameter is refused; a type to test against travels as a `comptime t: type<T>` parameter, and `v is t` is the concrete type's test in the function specialised for it.

`Registry.get` finds the first entry of a given type. The type is passed as a value, `r.get(Service)` and `r.get(Users)`, to a `comptime t: type<T>` parameter: `T` is inferred from `t` and never written twice. Because the parameter is `comptime`, each call compiles its own copy of `get`, and in that copy `e is t` is the ordinary run-time test `e is Service` (or `e is Users`), with the same answer on every target. The program prints `web` and `3`; rakun's `Service` record is one of the entries.

The generic form it replaces, `fn get<T>(self: Self) -> ?T` testing `e is T`, is refused at the test, `is-type-parameter`, naming `T` and this form. Type parameters are erased when the program runs, so no target could decide such a test. A comparison by name (`compiler.name(t)` as a key) is a program's own choice, never the language's answer.

Cells in this repository that prove it: none yet. rakun's catalogue narrows an entry with `is fn() -> T` (`modules/rakun/src/context.bp`); the plug-and-play registry that looks values up by type comes with front 165 s5.

[draft/main.bp](draft/main.bp)
