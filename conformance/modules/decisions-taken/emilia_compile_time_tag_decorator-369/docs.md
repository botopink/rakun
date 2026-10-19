# Decision 369 — emilia runs at compile time only: a tag decorator of its own, `#[emilia(…)]`, over tokens typed `Token`; class and rules computed at build — no `@Component`, no `@Task` at run time.

The example uses rakun-stylesheet (was `emilia`) with nothing of it left at run time. Each tag of
`card` carries `#[emilia(…)]` with its tokens: the decorator takes the declaration and the tokens as
build values, typed `Token`, so `.Pad.All.__4` and `.Text.Bold` resolve against the enum where they
are written. At build it computes the tag's class — the hash of the tokens in their order — and the
rules, and records them for rakun-bpp's `html`, which merges the class into the tag; it answers
nothing and produces no component and no task. `badgeClass` is the one class the program needs
outside a tag: `comptime className(…)` computes it at build, so the line holding it is a constant
starting `e_`. `main` renders the card and prints the markup with three emilia classes, `true` for
the prefix, and `true` for the render's sheet, which holds the rules the decorators recorded. The run-time
entry points — `emilia(tokens)`, `cls`, `named`, emilia's own `styled` — are gone.

Proving cells: none in this repository yet; the `conformance/rakun-stylesheet/` cells show the
tokens and their CSS in the run-time spelling the decision retires (for example
`conformance/rakun-stylesheet/getting-started/quickstart`), and the decorator comes with
`06-emilia/34` step 5 and `08-bpp/119` step 4.

[draft/main.bp](draft/main.bp)
