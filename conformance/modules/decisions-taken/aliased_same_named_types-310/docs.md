# Decision 310 — Two same-named types from two modules may be imported under aliases — 170 holds for types as for values:

std's `io.http` and rakun's `http` both declare a type `Response(status: i32, body: string)`. The example imports both, std's as `Upstream` and rakun's as `Served`, and uses them as two types. `relay` takes an `Upstream` (what a fetch answered) and returns a `Served` (what a rakun handler answers). It maps a 5xx to rakun's `Served.withStatus(502, "bad gateway")`, an associated constructor that only rakun's type has, and copies any other status and body across.

Each alias names its own type in every position: as an annotation (`val ok: Upstream`, `val a: Served`), as a constructor (`Upstream(status: 200, …)`), as a parameter or return type, and in `is`. `kind` tells the two apart at run time because each backend qualifies a type by its module. The program prints `200 {"id": 1}`, `502 bad gateway`, `upstream served` and `404`.

Writing the two imports without aliases binds `Response` twice and stays refused (`import-name-collision`).

Cells in this repository that prove it: none yet. The rule is the checker's and the backends'. rakun's cells that hold std's and rakun's `Response` side by side come with front 165 s7, the workspace's Conformance step.

[draft/main.bp](draft/main.bp)
