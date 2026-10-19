# Decision 298 — A decorator's meta is a typed value keyed by its type:

The example stores two kinds of meta on one entity and reads both back by their type. rakun-data's
`#[entity("cities")]` sets an `EntityMapping` on `City` — the table and its columns, one value of
that type per declaration. The program's own decorator `index` adds an `Index` each time it is
written, so `City`'s two `#[index]` annotations leave two values of one type. A type is either set
or added: had `index` called `compiler.setMeta`, the second annotation would be an error at it.

`main` reads at build. `compiler.typeInfo(City).meta(EntityMapping)` answers `?EntityMapping`,
so `?.table ?? ""` gives `cities`; `metaAll(Index)` answers `Index[]` in annotation order, and
the loop prints `name+state_name unique` then `state_name`. Neither read names `entity` or
`index`: the key is the record's type, so the decorator could be renamed, or a second decorator
could record an `Index` too, and the reader would not change; who may read the meta is whoever
can see `EntityMapping` and `Index`.

Proving cells: none in this repository yet; rakun-data's `#[entity]` records `EntityMapping` today
and its cells come with rakun 08 and front 130 step 8 (decision 298's steps), which write them
under this `conformance/`.

[draft/main.bp](draft/main.bp)
