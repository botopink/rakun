# Decision 767 — `botopink build` materialises the dependencies' cached `.beam` into the output (509 (4)'s materialisation, for `build` as for `run`), and rakun-ssr's `compileBeam` runs `erlc` only over the `.erl` with no `.beam` beside them — the app's own modules.

A small rakun application: one controller, dispatched once, printing `200 hello, ana`. What the decision fixes is what building it leaves on disk. `botopink build --target erlang` writes the application's own module as `.erl` and, beside it, the `.beam` of every module of its dependencies — `rakun` and what `rakun` reaches — materialised from the compiler's code cache, byte for byte the `.beam` that `botopink run` links. `rakun-ssr`'s build step then hands `erlc` only the `.erl` files that have no `.beam` next to them: this program's `main`, not the dependencies, so an edit recompiles the application's modules alone.

Cells of this repository that prove it: none yet. The materialisation in `build` is `machine-2/144` B-57, and `compileBeam` over the app's `.erl` alone is `machine-1/150` steps-onze 50 step 2; today `modules/rakun-ssr/src/cli/build.bp` compiles every `erl/*.erl`.

[draft/main.bp](draft/main.bp)
