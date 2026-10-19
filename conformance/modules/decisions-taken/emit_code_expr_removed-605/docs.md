# Decision 605 — `@emit`, `@code` and `@expr` are removed now, with `builtins.d.bp`, in B-139; nothing is parked and 604 gains no exception; 165 s10 lands before B-139.

`InvoiceService` is a rakun `#[service]` and carries the program's own `#[catalogued("billing")]`. Neither writes `@emit`, `@code` or `@expr`. `catalogued` registers the type by reading its name at build and putting a lambda in the init list with `compiler.init`, so `catalogue billing: InvoiceService` prints before `main`; it adds the static member `area()` with the typed `compiler.addMember`, its body a lambda answering the literal `"billing"`. rakun's `#[service]` does the same two things: it registers the type for the container's scan through `compiler.init` and adds the member `make()`. `main` prints `billing`, then `12.50` from the singleton `make()` builds.

The removed builtins are unknown names now (`unknown-builtin`): a generated type is a template text handed to `compiler.addType`, a generated function beside a `fn` is a run-time helper over a schema the marker registers, and `@expr(v)` is `v`.

Cells of this repository that prove it: `rakun/web/usage` and the `rakun/container/*` cells boot `#[service]` types; the migration of rakun's ~55 registrations is `2-libraries/165` s10.

[draft/main.bp](draft/main.bp)
