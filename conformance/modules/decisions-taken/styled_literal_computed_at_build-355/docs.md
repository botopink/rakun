# Decision 355 — A `styled` literal is computed at build when every hole is known at build; at render only when a hole is not.

The example has three rakun-style literals and renders them under a sheet that prints what it is
handed. `tab4` has no hole, and `code`'s one hole names `tab4`, a `val` whose own literal has none:
every hole of `code` is known at build, so its class and its rules — `tab-size:4;color:red` under
`.s_…` — are computed while the program is built, the emitted code holding them as constants, and
rendering it registers nothing. `badge`'s hole names the parameter `c`, a run-time value, so its
literal is built into a template with one slot and filled when it runs: rendering `badge("teal")`
registers `color:teal` under its class through the sheet the page provides, and the program prints
that line. The second `badge("teal")` answers the same class, its rules hashed from the filled text.
What decides is each hole's value, never the literal's text: `${tab4}` and `${c}` look alike.

Proving cells: none in this repository yet; rakun-style has no `conformance/` cells, and the
literal at build comes with `01-compiler/14` step 8 and front 119 step 1.

[draft/main.bp](draft/main.bp)
