# Decision 293 — A page reads its route through hooks, never a parameter.

A blog post page that takes no parameter. `#[page("blog/[slug]", paths: allPosts)]` names the pattern and the function that lists the paths to prerender; `allPosts` answers each path's segments with the `Post` handed to it. Inside `post`, `use params<BlogParams>()` answers the URL's segments as a record — `slug` typed `string` because the pattern's segment is — and `use pageData<Post>()` answers what `allPosts` handed this path. `Byline`, a component below the page, reads `use params<BlogParams>()` too, with no prop threaded through. Both hooks are unmarked: for a prerendered page they are known at build, so the page stays prerendered. `main` renders the path `/blog/hello` as the build would and prints the article.

`#[page]` checks the hooks against the pattern at build: a `BlogParams` field that is not a segment of `blog/[slug]`, or a `pageData<T>` whose `T` is not what `paths:` answers, is an error at the page naming the chain; a segment typed `id: i32` answers 404 unrendered for `/produto/abc`. A `route: PageContext` parameter, `paramsOf` and `pageData(route, schema)` are gone.

Cells of this repository that prove it: none yet. `rakun-bpp/router/router_hooks` reads the untyped `use params()` pairs, and `examples/rakun-ssr/blog` still takes `route: PageContext`; the typed hooks come with `05-jhonstart/26` step 11 and `01-checker` step 23.

[draft/main.bp](draft/main.bp)
