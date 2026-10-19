# Decision 626 — (a): inside a member a decorator adds, the owner is `decl` — the annotated declaration as code (613), so `decl.make()` is `ServerConfig.make()` —; and a decorator's `syntax decl` is typed by what the decorator requires of the declaration.

The example adds a member to a configuration type and calls the type's own factory from inside it.
`#[service]` gives `ServerConfig` its `make()`, filling `host` from the `server.host` property;
`#[checked("server")]` then adds the static member `check`. In the member's body the owner is
written `decl` — the annotated declaration as code — so `decl.make()` is `ServerConfig.make()`;
`Self` keeps its ordinary meaning and gains no second one there. `main` sets the property and prints
`server ok: 0.0.0.0`.

The handle's type says what the decorator needs. `checked` takes `syntax decl: Configurable`, a
behavior listing `make()`, so `decl.make()` is typed by it, and the check is structural: `ServerConfig`
writes no `implement Configurable`, it only has the member. A type annotated `#[checked(…)]` with no
`make()` — one without `#[service]` — is refused at the annotation, naming the missing member. Reading
the declaration at build inside the member, `compiler.name(decl)`, stays refused there
(`decorator-member-captures`); only the splice is admitted.

Proving cells: none in this repository yet; rakun's `#[configurationProperties]` adds its members as
text today, and 165 s10's `check` and `http` written this way bring the cells.

[draft/main.bp](draft/main.bp)
