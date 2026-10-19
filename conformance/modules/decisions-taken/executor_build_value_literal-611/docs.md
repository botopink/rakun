# Decision 611 — A build value an executor needs may be read in the decorator's body and enter the executor as a literal — `val declName = compiler.name(decl); compiler.init({ -> rkRegisterX(declName, decl); });` (cells `compile_executor_before_main`, `compile_executor_handle_typed`).

Two decorators register their declaration's name before `main`. `registered` reads `compiler.name(decl)` in its own body, at build, into `declName`, and the executor it hands `compiler.init` uses `declName`: the string enters the run-time lambda as a literal, so `registered Clock` prints. `announced` writes the same read inside the executor; `compiler.*` there is evaluated at build as well, and `announced Calendar` prints. rakun's `#[component]` on `Clock` registers it for the container's scan the first way. Then `main` prints `UTC` and `2026`.

Cells of this repository that prove it: none yet — `machine-1/165` s10 writes rakun's registrations in this form; `rakun/container/*` boots components registered so.

[draft/main.bp](draft/main.bp)
