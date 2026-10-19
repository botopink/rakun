# Decision 627 — (a): a `behavior` takes a static member through `compiler.addMember` as a type does, and inside an added member `decl` names the owner in a type position too — `fn() -> decl` is the annotated behavior.

`EchoService` is a rakun-restclient service interface: a `behavior` whose methods are HTTP exchanges. `#[httpExchange("echo")]` gives it a static member, `http()`, with `compiler.addMember`, the same way a decorator adds a member to a type. Inside the member the decorator writes `fn() -> decl`, and `decl` there is the annotated behavior in a type position, so `EchoService.http()` answers an `EchoService`. The program sets the group's base URL, calls `EchoService.http()`, passes the client where an `EchoService` is expected and prints `an EchoService for the group echo`; it makes no request. No generated `EchoService.Http` type is visible, and nothing is inferred: the member's return type is the behavior.

On a declaration that is no type (a `fn`, a `val`), `decl` in a type position is refused by the checker.

Cells in this repository that prove it: none yet. `modules/rakun-restclient/src/exchange.bp` still adds the twin type `EchoService.Http` with `compiler.addType`; the typed static comes with front 165 s10 / s11 and 144 B-140.

[draft/main.bp](draft/main.bp)
