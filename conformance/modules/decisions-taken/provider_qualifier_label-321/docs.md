# Decision 321 — Two providers of one type are told apart by a label, checked at compile time.

The example has two providers of `Database` and tells them apart by a label. `mainDb` is the
`#[primary]` one; `reportsDb` carries `#[qualifier("reports")]` — a label of the author's
choosing, which is not the function's name and could differ from it freely. The registry keys
each provider by its type and its label, recorded as typed meta.

`main` asks the context with the type itself: `ctx.resolveNamed(Database, "reports")` answers the
reports database, and `ctx.resolveNamed(Database)` with no label answers the `#[primary]` one. The
same marker on a constructor field asks for a labelled provider: `ReportJob(#[qualifier("reports")]
db: Database)` is built with the reports database, while `OrderJob`'s unlabelled `db` gets the
primary. The program prints `postgres://db/reports`, `postgres://db/main`, then both jobs'
targets.

The label is a `comptime` argument checked against the registry at build. Writing
`resolveNamed(Database, "mian")` is an error at the argument naming the labels that exist
(`reports`); a second provider labelled `"reports"`, a second `#[primary]`, or an unlabelled request
among several providers with no `#[primary]` are errors at build too.

Proving cells: `conformance/rakun/container/provides` (two qualified providers, the `#[primary]`
one answering an unqualified lookup, `resolveNamed` reaching the other) and
`conformance/rakun/container/resolve` (`rkFindNamed` by label). Both still name the type in text
and check the label at boot; the type-valued request and the build-time check are front 130 step 5
and rakun 04 step 6.

[draft/main.bp](draft/main.bp)
