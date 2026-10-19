# Decision 604 — No bodyless declaration but two: one with `#[compiler.external(…)]`, and `compiler.bp`'s `declare val compiler` (579). A marker is a decorator with an empty body.

The program marks its health checks with `#[healthCheck]`, a marker. A marker is a decorator whose body is empty, `{}`: it does nothing when it runs, and what it marks is still found, here at build by `compiler.find(with: healthCheck)`, which answers `database` and `disk` in source order. The two rakun functions the checks call, `rkProp` and `rkSetProp`, are bodyless and legal because each names its host source with `#[compiler.external(.Erlang(…))]` in `modules/rakun/src/runtime.bp`. The program prints `database, disk` and `true`.

Any other bodyless declaration is refused. Writing the marker as `declare fn healthCheck(syntax decl: unknown);` is `declare-without-implementation`, like any `declare fn` with no source. Apart from a declaration with `#[compiler.external(…)]`, the only bodyless declaration is std's `declare val compiler`.

Cells in this repository that prove it: none yet. rakun-bpp's `#[page]`, `#[layout]`, `#[template]` and `#[defaultView]` (`modules/rakun-bpp/src/routes.bp`) are written as functions with bodies; front 165 s10's codemod writes `{}` over the remaining markers.

[draft/main.bp](draft/main.bp)
