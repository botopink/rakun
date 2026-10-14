# dbcontext

> Package `dbcontext` of the rakun workspace — `repository/rakun/modules/dbcontext/` (a scaffold: no `botopink.json` yet, so not a member) · workspace rules: [`../../AGENTS.md`](../../AGENTS.md)

The persistence layer over erika (decision 398) — botopink's JPA: `#[entity(…)]` (it
records erika's `QueryTable`), `DbContext` (erika's `QueryContext`, over a `Driver` behavior),
`#[repository]` on a `behavior`, `#[query "…"]` (erika's grammar) and
`#[nativeQuery(…)]` (the driver's SQL), rows decoded into the declared answer by column
name. It depends on erika and std and names no framework (113): rakun-data supplies the drivers,
the container registration and the transactions. Filled by `specs/1.0.12-beta/04-rakun/143-dbcontext`;
until its steps land this repository holds only its scaffold. One consumer today (rakun-data): the
maintainer's exception to 115, stated in 398.
