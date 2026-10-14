# dbcontext

`decisions-taken.md` is generated — from the meta repository's `specs/<milestone>/decisions-taken.md` by `scripts/decisions-split.py`; edit it there, never here.

> Repository: `botopink/dbcontext` (`git@github.com:botopink/dbcontext.git`) · in the meta checkout: `repository/dbcontext/`

The persistence layer over erika (decision 398) — botopink's JPA: `#[entity(…)]` (it
records erika's `QueryTable`), `DbContext` (erika's `QueryContext`, over a `Driver` behavior),
`#[repository]` on a `behavior`, `#[query "…"]` (erika's grammar) and
`#[nativeQuery(…)]` (the driver's SQL), rows decoded into the declared answer by column
name. It depends on erika and std and names no framework (113): rakun-data supplies the drivers,
the container registration and the transactions. Filled by `specs/1.0.12-beta/04-rakun/143-dbcontext`;
until its steps land this repository holds only its scaffold. One consumer today (rakun-data): the
maintainer's exception to 115, stated in 398.

## Hooks

Every clone runs the shared pre-commit gate:

```sh
git config core.hooksPath scripts/git-hooks
```

The hook applies `botopink format` to the commit's staged source files before its gate (decision 524 — the
staged version, into the index; formatting never fails it) and runs the gate with `--jobs 2`.

`scripts/gate.sh [--staged] [--no-conformance] [--jobs <N>]` is the gate's one entry (one text in every
library repository, CI check 4; it runs `scripts/git-hooks/lib/runner-standalone.sh`): the pre-commit hook
runs `scripts/gate.sh --staged --no-conformance` (decision 470), and CI on a push to `feat` and a front's
Conformance step run it whole, which adds the last stage, `botopink cell check conformance/` over this
repository's `conformance/` cells (decisions 463, 464; the stage exists when the directory does). It knows no
job pool: `--jobs` is the total it may use, and the meta repository's `scripts/gate.sh run <repository>`
hands it its share.

`scripts/git-hooks/pre-commit` and `scripts/git-hooks/lib/runner-standalone.sh` are byte-identical
across the library repositories (the meta repository's CI check 4); edit them in one place and copy.
