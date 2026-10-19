# Decision 599 — The run-time field key goes; `compiler.Field<T>` is a build-time value; what is built at comptime is built through `compiler.*`, in botopink.

The example shows the one field key that remains: a build-time value. rakun-data's `#[index(.state)]`
and `#[unique(.name, .state)]` on `City` take `compiler.Field<City>` arguments written as `.state`
and `.name`; each is checked against `City`'s fields where it is written, so `#[index(.stat)]` is an
error at the argument naming the fields `City` has. Nothing of the key survives into the running
program — no `Field.of("state")`, no list of keys at run time, no `case` over a key.

`columns` reads the type the same way a decorator does: `compiler.fields(City)` inside a `comptime`
block is a botopink loop over the fields at build, and the list it builds is lifted into the
program, which prints `id,name,state,population`. A type or a value assembled at build is assembled
by such a body over `compiler.*`, never by a special case in the compiler.

Proving cells: none in this repository yet; rakun-data's `index` and `unique` and their cells are
front 150's, and the build-time `compiler.Field<T>` is botopink-lang's (B-140).

[draft/main.bp](draft/main.bp)
