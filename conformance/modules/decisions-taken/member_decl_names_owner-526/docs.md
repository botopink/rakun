# Decision 526 — A member's `@Decl` names its owner: `owner: ?Declared<unknown>` (`null` at module level), set by the checker when it runs a member's decorator.

The example has two methods with one name, `findById`, on two repositories, each annotated with
rakun-data's `#[query]`. The query decorator runs over a member, so the declaration it receives
names its owner, and the registration is named from the owner and the method together:
`UserRepository_findById` and `OrderRepository_findById`. Two same-named methods of two types never
collide, and nothing is hashed to keep them apart. `main` prints the registered queries.

The program's own decorator `traced` reads the same field. On `Ledger.audit` the owner is the
handle of `Ledger`, so the label is `Ledger.audit`; on the module-level function `audit` there is
no owner — `null` — and the label is the function's name alone. The second line prints
`audit,Ledger.audit`, in source order.

Proving cells: none in this repository yet; the owner field is a 144 step and rakun-data's
registration by owner is front 150 s30, which bring the cells.

[draft/main.bp](draft/main.bp)
