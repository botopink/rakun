# constraint

The reference text this cell shows (from `conformance/docs.md`, § An application constraint):

> Reach it from a field with `#[constraint("cpf")]`. `check` answers `""` when the
> value is acceptable and otherwise a message TEMPLATE — `{field}` and `{value}`
> are substituted by the reporter. A name nothing is registered under is a
> **violation** coded `unknownConstraint` naming what IS registered, at the first
> validation call; it is never a pass.
>
> Message templates resolve `rakun.validation.messages.<locale>.<code>` →
> `rakun.validation.messages.<code>` → the built-in default, over front 05's
> property table; the locale is `rakun.validation.locale`. A template naming a
> placeholder the constraint does not have is left as written, because a visible
> `{limit}` in an error message is a bug report and an empty string is not.

## Measured

The original registered at module level (`val __cpf = …; val __cpfRegistration = …`), which leaves `__cpf` unbound in the erlang emission; the cell registers in `main`. The type is written `CpfConstraint()` (a body without parentheses is a namespace type).
