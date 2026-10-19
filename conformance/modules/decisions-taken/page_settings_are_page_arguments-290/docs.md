# Decision 290 — No segment configuration; a page's settings are `#[page]` arguments.

The example is a blog post page that carries its settings where it is declared. The one
`#[page(…)]` line names the segment `blog/[slug]`, the `paths:` it prerenders (`hello` and
`second`), `revalidate: hours(1)` — a `Duration` from std's `io.clock`, after which a prerendered
post is regenerated — and `dynamicParams: true`, so a slug outside `paths` (`/blog/late`) is
rendered on demand rather than answered 404.

Nothing else configures the segment. There is no `registerSegmentConfig("blog/[slug]", …)` call
and no `SegmentConfig` record, so no setting is inherited from a layout above; there is no
`dynamic` to force the page static or dynamic — whether `Post` renders at build or per request is
read from the hooks its body uses (here only `params`, so it is static for the listed paths) — and
no `fetchCache`. `main` reads the page's recorded segment back with `compiler.typeInfo(Post)` at
build and prints it, then renders the listed post.

Proving cells: none in this repository yet; rakun-app still registers a `SegmentConfig`
(`modules/rakun-app/src/segment_config.bp`), and the page arguments come with `04-rakun/22` step 8
and `05-jhonstart/26` step 10.

[draft/main.bp](draft/main.bp)
