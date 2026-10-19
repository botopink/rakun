# Decision 669 — Code a decorator writes resolves in the decorator's module, a type it builds included; the one way to a caller's names is `compiler.lookup`.

The example puts a decorator in a module of its own, `audit.bp`, and uses it from `main.bp`. The
decorator `auditable` writes two pieces of code: an executor calling `record(owner)` and a member
`lastAudit` answering `?AuditEntry`. `record`, `entries` and `AuditEntry` are declared in `audit.bp`
and imported by nobody: the code a decorator hands the compiler resolves where it was written, in the
decorator's module, so `main.bp` does not import them and they do not leak into it. The member added
to `PaymentService` names `AuditEntry` as its return type all the same, and `main` reads
`PaymentService.lastAudit()?.owner` without knowing where the type comes from.

What the user writes in an annotation resolves in the annotation's module instead, and a decorator
that needs one of the caller's names reaches it only through `compiler.lookup`; a name that exists
only in `main.bp`, written in the decorator's code, is refused at the decorator. `main` prints
`charged 990`, then `1 PaymentService`.

Proving cells: none in this repository yet; rakun-data's `#[transactional]` builds its proxy over
names of its own module, and 165 s10 and s11 bring the cells (`built_type_names_decorator_module` is
botopink-lang's).

[draft/main.bp](draft/main.bp)

[draft/audit.bp](draft/audit.bp)
