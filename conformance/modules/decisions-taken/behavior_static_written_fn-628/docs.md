# Decision 628 — In a `behavior`, a member without `self` is a static of the behavior and is written `fn`, never `default fn`: `fn unit() -> Self { … }` with a body is the behavior's own function, called `Shape.unit()`; `fn make() -> Self;` without a body is a static each implementor provides (626's `Configurable`); `default fn` is an instance member with an overridable default body, and nothing else.

rakun's configuration records seen as a `behavior`, `Configurable`, with the three kinds of member side by side. `make()` has no `self` and no body: each implementor provides it, and `ServerConfig.make()` and `MailConfig.make()` are each type's own. `prefixOf(key)` has no `self` and a body: it is the behavior's own static, written `fn`, called `Configurable.prefixOf(…)` and owned by the behavior alone. `describe` has `self` and is written `default fn`: `ServerConfig` overrides it with `localhost:8080`, `MailConfig` keeps the default `configured`. The program prints `server -> localhost:8080`, then `mail -> configured`.

Writing `default fn prefixOf(key: string)` — `default` on a member without `self` — is refused at the modifier, `default-on-static`, naming `fn` as the fix; an implementor does not override the behavior's own static.

Cells of this repository that prove it: none yet — rakun's one `default fn` without `self` drops `default` in front 165 s11.

[draft/main.bp](draft/main.bp)
