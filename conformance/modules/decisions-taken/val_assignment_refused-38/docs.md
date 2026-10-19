# Decision 38 — A `val` is immutable

The example is refused. `status` picks the code a rakun handler answers: it declares `val code = 200`
and, when the resource is not found, assigns `code = 404`. A `val` is never assigned again, so the
checker refuses the program at that assignment, located at `code = 404`, and the message names `var`
— the declaration the function needed. With `var code = 200;` the program builds and prints `404` on
every target; as written it never reaches a backend, so no target is left to fail at run time the way
commonJS's `const` once did while the other targets agreed in silence.

Proving cells: none in this repository; the refusal is the compiler's, proved by botopink-lang's
cells, and rakun's sources hold no assignment to a `val`.

[draft/main.bp](draft/main.bp)
