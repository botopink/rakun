# Decision 250 — † std's `io.random.bool()` is dropped, not renamed; `coin()` is the boolean draw

An A/B split the way a rakun handler would pick a variant per request. The program draws `random.coin()` two hundred times from `io.random`; each draw is typed `bool` where it is bound (`val flag: bool`), so it stands directly as the condition of `if` and as the argument of `variant`, with no comparison around it. The program counts the heads and collects the variants it saw, then prints `true` twice: the count lies between none and all of the draws, and at least one variant was served. Nothing printed depends on the draw itself.

There is no `random.bool()` to call: the name is gone, not kept as an alias of `coin()`, and a call to it is an unknown member of `io.random`.

Cells of this repository that prove it: none yet — rakun calls no boolean draw today; the rule is std's (`02/97` step 10).

[draft/main.bp](draft/main.bp)
