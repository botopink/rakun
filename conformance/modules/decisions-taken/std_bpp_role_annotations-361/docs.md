# Decision 361 — std's module `bpp` holds the four role annotations; jhonstart is one package; the manifest names it alone.

The example is the framework side of the contract a `.bpp` file is compiled against. std's `bpp`
module declares four role annotations, and this module marks the declarations that play them:
`#[bpp.html]` on `html`, the template a file's markup unfolds to; `#[bpp.style]` on `style`, the
template its `--- style ---` section unfolds to; and, because a prelude is a module and a module
takes no annotation, `#[bpp.htmlPrelude]` and `#[bpp.stylePrelude]` on two marker `val`s,
`bpp.Prelude()`, whose module's imports are what a file sees without importing.

`rakun-bpp` is that package, one package: its style function and the `StyledContext` provider are
in it, beside the markup, so a project's manifest names it alone, `"bpp": "rakun-bpp"`. The
toolchain finds each role by these annotations and knows nothing else of the package: `html`
exactly once (a second `#[bpp.html]`, or none, is an error at the manifest key naming the
declarations), the other three at most once. `main` uses both templates directly, the way an
unfolded file does, and prints the markup and the class the style answered.

Proving cells: `conformance/rakun-bpp/html-dsl/html_dsl_prelude` (the markup sees exactly the tags
its prelude imports). The roles found through the manifest come with `08-bpp/116` step 1 and 119
steps 2–5.

[draft/main.bp](draft/main.bp)
