# Decision 341 — A decorator body may call a host function that answers on the comptime runtime

The program schedules a nightly report with rakun-scheduling and gives the task a key computed at build. `taskKey` is the program's own decorator on the method `nightly`; its body reads the method's name and calls two host functions while the program is being compiled: `toUpper` and std's `contentHash`. Both answer on the comptime runtime through their `std:` cells, so the key, `NIGHTLY-` followed by the first eight characters of the name's content hash, is the same whichever target the program is then built for. The decorator records it with `compiler.setMeta`, and `main` reads every key back at build through `compiler.find(with: taskKey)` and prints it. `#[service]` and `#[scheduler]` on `Reports` and `#[scheduled("0 0 6 * * *")]` on the method register the task with rakun as usual.

A host function with neither cell is refused at the call when the package that holds the decorator is compiled, never when a consumer builds against it: `comptime-host-cell-unavailable`, naming both sources it tried. A source that runs only on erlang (`.Erlang(…)`) never runs at build, and a JavaScript-only source never serves a decorator.

Cells in this repository that prove it: none yet. rakun-scheduling's `#[scheduled]` (`modules/rakun-scheduling/src/markers.bp`) still restates its cron rules because an imported function is refused in a decorator body today; it can call `cron.bp` directly once 144 B-00c lands, and its cells come with front 165's steps for the package.

[draft/main.bp](draft/main.bp)
