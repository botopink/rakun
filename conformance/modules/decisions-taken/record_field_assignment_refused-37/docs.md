# Decision 37 — Is a record immutable?

The example is the refused program. A handler builds rakun's `Response` with `Response.ok("hello")`, keeps a second name for it (`alias`), and then tries to change its status in place twice: through a parameter, `res.status = 404` inside `markMissing`, and directly, `res.status = 201` in `main`. Both are field assignments, and the checker refuses the program at the first one in the source, located at `res.status = 404`: a `Response` is immutable, and the message names the update form — a new `Response` built from the old one, `Response(..res, status: <value>)` (the spread of decisions 359 and 529). Nothing runs: no backend gets to show whether `alias` would have seen the change.

Written with the update form, the program answers a fresh record and leaves `res` and `alias` as they were — `val` then holds the value, not only the binding.

Cells of this repository that prove it: none yet. rakun's sources build a changed `Response` with its constructors (`Response.withStatus`); the refusal itself is the compiler's, and its cell is this one once promoted (front 166 s4).

[draft/main.bp](draft/main.bp)
