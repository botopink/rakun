# rakun-data

> Package `rakun-data` of the rakun workspace — `repository/rakun/modules/rakun-data/` · workspace rules: [`../../AGENTS.md`](../../AGENTS.md)

DataSource + pool, the ETS / PostgreSQL / MySQL arms, `SqlTemplate`, `#[transactional]`, migrations, outbox / saga /
two-phase commit and the devtools console — erlang. Depends on `rakun`, `rakun-service` and, as an external library
outside this repository, `query` (`botopink/query`).

## The entity / context / repository layer (to come)

`dbcontext` was a repository that never held source: its plan was an `AGENTS.md` and its specs, which are now 150
s48–s51 (`steps-dbcontext.md`). Folded here (front 165 s3), the layer will live under `rakun-data/src/{entity,context,repository}/`.

The persistence layer over `query` (decision 398) — botopink's JPA: `#[entity(…)]` (it
records query's `QueryTable`), `DbContext` (query's `QueryContext`, over a `Driver` behavior),
`#[repository]` on a `behavior`, `#[query "…"]` (query's grammar) and
`#[nativeQuery(…)]` (the driver's SQL), rows decoded into the declared answer by column
name. It depends on `query` and std and names no framework (113): the drivers, the container registration and the
transactions are this package's own. Until the steps land this package holds none of it.
