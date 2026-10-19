# Decision 606 — No `#[builtin]` and no `@name`: the types and behaviors a program reaches without an import are declared in `primitives.bp`; what the compiler does is a member of `compiler`; the two std functions left are imported.

The example uses each of the three places a name can come from. `Result<i64, string>` is written
bare, as `string` and `i64` are: it is declared in the prelude, `primitives.bp`, which every program
sees without an import. `print` and `panic` are the two std functions left, and each is imported from
the module that owns it — `terminal.print` from `io.terminal`, `panic` from `failure`, beside
`Failure` and `attempt`. What the compiler itself does is a member of `compiler`: the host binding
`nowMillis` is declared with `#[compiler.external(…)]`, and `main` asks
`comptime compiler.typeInfo(PortController)` for the controller's methods at build.

No name in the program carries an `@`. `parsePort` answers `Ok(8080)` here, so `main` prints the
handler count, then `8080 true`; an invalid port in the request answers `400` from the controller,
and an invalid one at startup is `panic(e)`, a defect that ends the program.

Proving cells: every cell of this repository imports `print` from `io.terminal` (for example
`conformance/rakun/web/usage`, `conformance/rakun/container/provides`); none yet writes the
`@`-free spelling of `typeInfo`, which B-139's codemod brings to the libraries.

[draft/main.bp](draft/main.bp)
