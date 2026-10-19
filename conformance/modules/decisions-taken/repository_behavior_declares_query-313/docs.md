# Decision 313 — A repository is a `behavior` annotated `#[repository]`; each method declares its query — erika's or native SQL

A rakun-data repository written as a `behavior`. `User` is an `#[entity]`; `Users` is annotated `#[repository]` and each of its methods declares its query. `find` carries `#[query "…"]`, a query checked against `User` at build, its SQL and its parameter `id` recorded as the method's meta and checked against the declared answer `Result<?User, StoreError>`. `named` carries `#[nativeQuery("…")]`, the driver's SQL as a literal string handed over verbatim: its `:name` placeholder matches the parameter `name`, its leading keyword is `select`, and the rows decode into `User[]` by column name. `#[repository]` generates `Users.Sql(ctx)` implementing the behavior, the factory `Users.of(ctx)` and its registration by type in rakun's container, so `main` resolves a `Users` and `greet` — which depends on the behavior alone — reads one user through it.

Each refusal is at the annotation or the method: a placeholder no parameter answers or a parameter no placeholder uses, a leading keyword outside SELECT, INSERT, UPDATE, DELETE, WITH and CALL, a native query built by concatenation, and a method with neither annotation. A `?T` answer meeting more than one row is the `single()` panic.

Cells of this repository that prove it: none yet — rakun-data's `#[query]` today gives a type's method an `<m>Sql()` member and `rkRegisterQuery`; the behavior form arrives with rakun 08 step 7 and `04-rakun/137`.

[draft/main.bp](draft/main.bp)
