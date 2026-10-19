# Decision 578 — No `-> expr`: a template is marked by its `syntax` text parameter and returns a type, `anyvalue` or `anytype`; `anytype` is the bare `type`.

Both functions are templates because their first parameter is `syntax q: string`, the template text; nothing in the return type marks them. They are called only with the template syntax, `` path @`/users/:id` `` and `` reply @`hello` ``. `path` answers an ordinary `string`: it reads its text with `compiler.text(q)`, refuses at build a path that does not start with `/`, and the call is the string. `reply` answers `anyvalue`: it builds the code `Response.ok("hello")` from the typed AST with `compiler.ast`, so the call takes the type of that code, rakun's `Response`, checked where the call stands (`val r: Response`). The program prints `/users/:id` and `200 hello`.

A template that answers a type is declared `-> anytype` and builds it with `compiler.buildType`. There is no `-> syntax T` return and no `-> @Expr<T>`, and `anyvalue` is written nowhere but a template's return.

Cells in this repository that prove it: none yet. rakun-bpp's `html` markup template (`modules/rakun-bpp/src/html/`) and rakun-stylesheet's class templates are the library's templates; they take this form in front 165 s10.

[draft/main.bp](draft/main.bp)
