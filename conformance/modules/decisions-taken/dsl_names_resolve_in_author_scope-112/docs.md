# Decision 112 — DSL hygiene: each name resolves in the scope of whoever wrote it

The example renders one paragraph through rakun-bpp's `html` template, which is a DSL whose expansion has two authors. The page writes the markup `<p>hello, ${who}</p>`. The template answers the builder code that stands at the call: `p([htmlText(who)], attrs: …)`.

The words the page wrote resolve in the page's module. `p` is the builder the page imports from `element`, and the template asks for it with `compiler.lookup`, which answers the declaration `p` itself and never an alias the page might have used. `who` is the local of `main`. The frame the template wrote resolves in `html.bp`, the library's own module: `htmlText` is a private function of rakun-bpp, and the page never imports it.

The page also declares an `htmlText` of its own, which answers `captured: …`, and the expansion does not pick it up: the paragraph still renders `<p>hello, ana</p>`. The program prints that line, and then `captured: ana` from the page's own call to its own function.

Cells in this repository that prove it: `rakun-bpp/html-dsl/html_dsl_hole` (a `${…}` hole typed at the call, inside the library's frame) and `rakun-bpp/html-dsl/html_dsl_prelude` (the page imports only the tags it writes, while the expansion's helpers resolve in `html.bp`).

[draft/main.bp](draft/main.bp)
