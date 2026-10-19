# Decision 398 — The persistence layer is a library of its own over erika — `dbcontext` (`botopink/dbcontext` at `repository/dbcontext`, 326's rule), botopink's JPA.

In force under 724: dbcontext is folded into the workspace package `rakun-data`, and erika is the external library `query`. The split between the query language and the persistence layer stays as this decision draws it.

The example is a small persistence layer for users. `#[entity("users")]` maps `User` to its table and records `query`'s `QueryTable` meta, and `#[column("user_name")]` gives the field `name` another column. `Users` is a `behavior` annotated `#[repository]`, with one method per statement. `find` carries a `#[query @`…`]` annotation written in `query`'s grammar and checked against `User` at build, and `byActive` carries a `#[nativeQuery("…")]` holding the driver's own SQL, its `:active` placeholder matched by name to the parameter. From those annotations `#[repository]` generates the implementation, and `Users.of(ctx)` answers it over a `DbContext`, which is `query`'s `QueryContext` running on a `Driver`.

`Recorder` stands in for a real driver: it prints each statement and answers one row, and the row is decoded into `User` by column name. The program prints the `find` statement rendered from the query, then `ana`, then the native statement as written, then `7:ana`. `query` itself names no persistence library, and this layer names no framework. The real drivers (PostgreSQL, ETS), the container's registration of `DbContext` and of each repository by type, `#[transactional]` and the `/actuator/sql` inventory are `rakun-data`'s own.

Cells in this repository that prove it: none yet. The entity, context and repository layer comes with front 150 s48–s50 (the former 153 s1–s3); today `modules/rakun-data/src/orm/` holds the older `#[entity]` mapping and `sql/query.bp` the older `#[query]`, and until those steps land the example does not build.

[draft/main.bp](draft/main.bp)
