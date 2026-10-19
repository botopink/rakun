# Decision 663 — A decorator is always a function, and `Annotation` goes: no type or enum is an annotation by implementing a behavior; `#[name(…)]` names a function whose first parameter is `syntax decl`, and the data an annotation carries is a record the decorator records with `compiler.setMeta`. There is no `Decorator` type (666): a decorator's name at build is a declaration handle.

Every annotation in the program names a function. `#[service]` is rakun's `service` from `modules/rakun/src/decorators.bp`, and `#[owner(team: "billing")]` is the program's `owner`, whose first parameter, `syntax decl`, is the annotated declaration. The data the annotation carries is the record `Owner`, which `owner` records with `compiler.setMeta`. `Owner` is no annotation itself, and nothing implements an `Annotation` behavior. At build, `compiler.find(with: owner)` answers the two annotated types and `compiler.meta<Owner>(d)` reads each one's record back. The program prints `Invoices -> billing, Mailer -> mail` and `42`, the latter from `Invoices.make()`, the singleton factory `#[service]` added.

Writing `#[Owner(team: "billing")]` with the type's name is refused, because a name after `#[` that is no decorator function is not an annotation. Enums used as annotation keys follow the same rule: `#[stage(.Any)]` and `#[beamMemory(.Ets(keyed: true))]` are std decorators taking the enum value. A decorator's name at build is a declaration handle; there is no `Decorator` type.

Cells in this repository that prove it: `rakun/web/usage` (rakun's `#[service]`, `#[restController]`, `#[route]` and `#[getMapping]`, each a decorator function) and `rakun/plug-and-play/boot_modules` (`#[rakun.module]`, `#[rakun.config]`).

[draft/main.bp](draft/main.bp)
