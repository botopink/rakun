# Decision 716 — The declared type of a decorator's `syntax decl` parameter is the contract the annotated declaration must meet, and every tree the decorator writes is checked once, against that type; `decl` is the declaration as code in every tree, a member included.

Two decorators whose `syntax decl` parameter carries its contract. `configured` takes `decl: Configurable`, a behavior: it admits `ServerConfig`, which implements it, and inside both trees it writes — the `compiler.init` executor and the added member `bound` — `decl.make().key()` is typed by `Configurable`. `route` takes `decl: fn(req: Request) -> Response`: it admits the handler `status`, and in the executor `decl(req)` is a call of that function, handed to rakun's `rkRegisterRoute`. Each tree is checked once, at the decorator, against the declared type; the annotation is checked only against the contract. The program prints `bound to server`, the catalogue's `server`, then `up` from `/status`.

Two refusals fall out. Declared `syntax decl: unknown`, the decorator could not write `decl.make()`: `unknown` has no member `make`, refused at the decorator. `#[configured]` on a type that does not `implement Configurable` is refused at the annotation, naming the type and the behavior. No error surfaces inside an executor with a `called from` line.

Cells of this repository that prove it: none yet — rakun's decorators type their `decl` in front 165 s10, after 144 B-137 / B-145.

[draft/main.bp](draft/main.bp)
