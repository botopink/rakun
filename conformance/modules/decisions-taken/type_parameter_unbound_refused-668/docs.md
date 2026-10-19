# Decision 668 — A function's type parameter is always bound by a parameter, never by the return type alone.

The refused program. `Registry.get<T>(self, name) -> ?T` is the shape rakun's container lookups have today (`rkFind<T>(typeName)`, `rkSessCurrent<S>()`): `T` occurs in the return type and in no parameter. The declaration is refused, located at it, `type-parameter-unbound`, naming `T` — the caller's annotation (`val found: ?string`) is a wish, not a binding, and the body cannot act on a type it never receives.

The bound forms build: a parameter that carries the type, `get(self: Self, comptime t: type<T>, name: string)` called `registry.get(string, "DataSource")`, or an answer of `unknown` the caller reads.

Cells of this repository that prove it: none yet — rakun's 23 unbound host bindings and its 12 cell sites gain the binding parameter in front 165 s10, after 144 B-152 lands the refusal.

[draft/main.bp](draft/main.bp)
