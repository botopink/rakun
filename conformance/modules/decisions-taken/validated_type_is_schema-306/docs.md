# Decision 306 — The type is the only schema, and `#[schema]` becomes `#[validated]`.

The example is a rakun handler for a signup form, and `Signup` is the only description of the form anywhere in the program. `#[validated]` on the record gives it both halves: the checking half, `validate()` and `constraints()`, and the parsing half, here `Signup.decode(body)`, which turns the request's JSON text into a `Signup` or a `ValidationReport`. The field markers say what a schema value used to say: `#[email]` and `#[minValue(18)]` constrain one field, and `#[each(email, lowercased)]` applies its markers to every item of `guests`.

`register` reads the parse with one `case`, so a good body answers `201` and a bad one `400` with every violation at its field. The program prints `201 ana@example.com +1`, then `400` followed by the codes for `email`, `age` and the guest that is not lowercase, then `false` for the `Signup` built in code with a bad address, which never went through a parse, and `true` for the constraint table being there.

There is no `#[schema]`, no `Schema<T>` or `Codec<A, B>` value to build next to the type, and no `schemas.*` or `checks.*` call in the program. Another library that needs the shape takes the type itself as a `comptime` type parameter and refuses one that carries no `Validated` meta.

Cells in this repository that prove it: `rakun/validation/validated` (the checking half on a rakun handler). `Signup.decode` and the `#[each(…)]` marker are validation's (front 146), and rakun consumes them as they land there.

[draft/main.bp](draft/main.bp)
