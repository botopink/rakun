# Decision 576 — `@Expr` and `@Decl` go whole; the template model hangs off `compiler`.

The page `about` carries two decorators: rakun-bpp's `#[page("/about")]` and the program's own `#[audited("docs-team")]`. Both are functions whose first parameter is `syntax decl: unknown`, an opaque handle: `audited` reads it with `compiler.kind` and `compiler.name`, fails at it with `compiler.fail(…, at: decl)` when it marks anything but a function, records the typed meta record `Audit` with `compiler.setMeta`, and puts its registration in the program's init list with `compiler.init`, so `audited about by docs-team` prints before `main` runs. `main` reads both meta records back under `comptime` — `compiler.meta<RouteSegment>(about)` gives `/about`, the segment `#[page]` wrote; `compiler.meta<Audit>(about)` gives `docs-team` — and renders the page, `<p>about /about</p>`. `DeclKind` is imported from std's `compiler` module like any type of it.

No `@Expr`, `@Decl`, `Declared<T>`, string meta or `@TypeInfo.all` remains: a catalogue of pages is what each marker registers through `compiler.init`, never a run-time scan.

Cells of this repository that prove it: none yet — `2-libraries/165` s10 migrates rakun and rakun-bpp; `rakun/web/usage` still reads `@TypeInfo.all`.

[draft/main.bp](draft/main.bp)
