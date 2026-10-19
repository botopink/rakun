# Decision 579 — `compiler` is not a keyword: it is a value std declares, imported like any name.

The program imports `compiler` from std like any name and its decorator `named` reads the annotated declaration with it: `compiler.name(decl)` at build, and `compiler.init` registers `named BuildService`, printed before `main`. rakun's `#[service]` on the same type reads its own `compiler`, imported in rakun's module, so the program needs no import for it. Outside the decorator `compiler` is an ordinary name — the field `Toolchain.compiler` and the parameter `compiler` of `describe` — and `main` prints `built by botopink`; the last line reads `compiler.module` under `comptime`, the module the read is written in.

A file that names `compiler` without the import gets the unbound-name error; reading it in a run-time body without `comptime`, passing it as an argument or storing it stays refused (`compiler-at-run-time`, `compiler-escapes`), whatever alias it was imported under.

Cells of this repository that prove it: none yet — `2-libraries/165` s10 adds the import to every rakun file that reads `compiler.`; `rakun/web/usage` uses `#[service]`.

[draft/main.bp](draft/main.bp)
