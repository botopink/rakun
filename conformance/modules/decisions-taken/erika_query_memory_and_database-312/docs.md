# Decision 312 — erika queries a database too, as LINQ does: one grammar, two targets, picked by the source.

In force under 724's names: erika is the `query` library, and the database context lives in `rakun-data`.

The example writes one query language against two sources. `activeInMemory` queries the array `people` and runs in memory, on the fluent pipeline; it prints `ana`. `Users` writes the same grammar on `rakun-data`'s `DbContext`, `self.db.query @`…``, and there `from User` names the type `User`, imported into the module and resolved where the query is written, so hover and go-to-definition reach it. Its table and columns come from the `QueryTable` meta that `#[entity("users")]` records, read at build. The query is rendered to SQL at build, and `Recorder`, a driver that prints each statement, shows what reaches the database: the `select … from users where active = true` statement with no parameters, then the `byId` statement with one parameter. The `${id}` hole is a bound parameter, never spliced into the text.

The number of rows is part of the query. `byId` answers `Result<?User, StoreError>` and writes `limit 1`; `active` answers a list and writes none. Swapping them is a compile error at the query, and so is a field `User` does not have, or a `from User` with no import of `User`. The same query can also sit on a repository method as `#[query @`…`]` (398).

Cells in this repository that prove it: none yet. `DbContext`, `Driver` and `#[entity]`'s `QueryTable` come with front 150 s48 (the former 153 s1), `QueryParam` with 145 s1 in `query`, and the template method on the context with 144 B-18. Until those land the example does not build.

[draft/main.bp](draft/main.bp)
