# Decision 285 — The toolchain knows these things about `.bpp`:

The program declares two views and gives each its role with `rakun-bpp`'s decorators: `#[page("blog/[slug]")]` on `Whatever` and `#[layout("blog")]` on `Shell`. Neither the function names nor the file name say anything, because the toolchain applies no decorator by name. `main` reads the meta each decorator recorded, at build, and prints `blog/[slug]` and `blog`.

In a `.bpp` application the same happens without the author writing the decorator. The toolchain unfolds `app/blog/[slug]/page.bpp` onto the default function of the package the manifest's `"bpp"` names, and knows only what std's four `bpp` annotations mark there: `#[bpp.html]` (the markup's unfold target), `#[bpp.style]` and the two preludes. The route table `rakun-app` generates at build from `routing`'s file kinds then calls `page("blog/[slug]", f)` / `layout(…)` as comptime functions on each unfolded default function, reading its hooks list. `"bppKinds"` is gone from the package's manifest.

Cells in this repository that prove it: none yet. `rakun-bpp/html-dsl/html_dsl_prelude` shows the prelude half. The route table calling the roles arrives with front 150 s13 step 7 and s36 step 10.

[draft/main.bp](draft/main.bp)
