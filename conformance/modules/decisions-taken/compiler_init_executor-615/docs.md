# Decision 615 — `compiler.compile` is renamed `compiler.init`: `init(syntax executor: fn())` puts the executor in the program's init list, at the annotated declaration's position (580), to run once before `main`.

`compiler.init(executor)` puts run-time code in the program's init list, at the annotated declaration's position, to run once before `main`. `#[step("first")]` on `boot` adds two executors, so `first boot` and `  then boot` print in that order; `#[step("second")]` on the rakun `#[service]` `MailService` adds `second MailService` and `  then MailService` after them, since `boot` is written first — and rakun's `#[service]` puts its own scan registration in the same list. `#[greeted]` on `banner` hands `compiler.init` the named function `hello`, so `hello from a named executor` prints last of the executors. Then `main` prints `main`, `boot`, `banner`.

`compiler.init` is a decorator's output: written outside a decorator it is refused (`compiler-output-outside-decorator`).

Cells of this repository that prove it: none yet — `machine-1/165` s10 renames rakun's `compiler.compile` sites; `rakun/web/usage` boots `#[service]` types.

[draft/main.bp](draft/main.bp)
