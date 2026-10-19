# Decision 109 — A module atom starts with its package, and the declaration boundary is `@@`

The example asks the BEAM for the atoms the program runs under. `tagOf` reads the tag of a record
value — the atom of the type that built it — and `moduleOf` the module the code runs in, both as
text through one erlang host call each. `Response.ok("hi")` is a value of rakun's `Response`,
declared in the module `http` of the package `rakun`, so its tag is `rakun@http@@Response`: the
package first, `@` for each path segment, `@@` before the declaration. `Greeting` is this program's
own type in `src/main.bp`, and its tag starts with the name of the program's own `botopink.json`
(lowercased, every character outside `[a-z0-9_@]` folded to `_`), then `@main@@Greeting` — the
declaration keeps its capital, the module half stays lowercase because it is also a file name.
`moduleOf()` prints the same package and path without the `@@` part. Two packages that both have
a `main` or an `http` module are two atoms, and every atom holds an `@`, so none of them meets an
OTP module such as `math`.

Proving cells: none in this repository; the naming is the compiler's (front 13), proved by
botopink-lang's cells, and rakun's sidecars that spell a tag (`'rakun@http@@Response'`) rely on it.

[draft/main.bp](draft/main.bp)
