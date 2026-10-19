# Decision 583 — Every function is typed where it is written.

Every lambda in the example has its type fixed by where it stands. The one passed to `onStop` inside the `web` module is typed by that parameter, `fn()`. The one passed to `answers.map` gets `r: Response` from `map`'s parameter, and the line prints the statuses `[200, 201, 404]`. `isError` is an annotated `val`, `fn(Response) -> bool`, so its lambda checks against the annotation, and filtering by it prints `1`. `statusOf` returns a lambda, and the declared return type `fn(Response) -> i32` types it.

`twice` is bound with no annotation, so nothing would type a lambda there. It is written in the typed form instead, `fn(n: i32) -> i32 { … }`, and prints `42`. Writing it `val twice = { n -> n * 2 };` would be refused `lambda-untyped` at the lambda, with the message "nothing types this lambda — write fn(n: T) -> R { … } or type the val". A later call like `twice(21)` never types `n`. When `rakun.stop()` runs, the `onStop` handler prints `web stops`.

Cells in this repository that prove it: none yet. rakun's sixteen untyped `val`s bound to a lambda are migrated by hand, in the decision's migration commit for this library (front 144, machine 1). The cells for the rule come with front 165 s7, the workspace's Conformance step.

[draft/main.bp](draft/main.bp)
