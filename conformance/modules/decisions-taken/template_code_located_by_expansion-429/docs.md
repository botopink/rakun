# Decision 429 — The compiler locates template-built code by its expansion — every loc-keyed plan keyed by (expansion, offset); this fix lands first and pauses the fronts that would add a padded expansion.

Two components in one module expand the same `html` literal, character for character: each builds a list whose hole maps the items through a lambda and reads a field of each. The two expansions build the same code at the same offsets, and the compiler tells their nodes apart by the expansion each belongs to, so on erlang the two lambdas and the two field accesses are two plans and the program prints `<ul><li>a</li><li>b</li></ul>` and `<ul><li>c</li></ul>`. `rakun-bpp`'s `html` builds its code as the literal reads, with no padding to push each expansion to its own line and column.

A diagnostic inside either expansion still points the reader at the literal in the source, not at the built text.

Cells of this repository that prove it: none yet. `html.bp` still pads the built code to the literal's own line and column (its header); the fix is `01-checker` step 41, and `04-rakun/137` step 4 and `08-bpp/116` step 4 drop the padding after it.

[draft/main.bp](draft/main.bp)
