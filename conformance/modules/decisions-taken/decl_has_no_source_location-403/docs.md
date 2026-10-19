# Decision 403 — `@Decl` carries no source location: a decorator's output never depends on where its file sits.

The program has two pages and neither learns its route from where its file sits. `BlogPost` carries `#[page("blog/[slug]")]`: the route is the decorator's argument, written by the author, and the decorator's output (the `RouteSegment` it records) is the same wherever the file is moved. `About` has no annotation; it reaches the router the way the file-convention route table rakun-app generates from the `app/` tree passes a page — `jhPage("about", About)`, the route again an argument. A page reads its segments by asking, not by its location: `pageParams(route).get("slug")` answers `hello`. The program prints `<div><h1>Post hello</h1></div>` and `<div><p>About /about</p></div>`. A decorator may call `compiler.src()` to report at the annotated declaration (734), and `compiler.fail(…, at: decl)` reports at the annotation or the argument; what it may not do is derive a route, or any other output, from the file's path.

Cells in this repository that prove it: none yet; the pages' cells come with rakun-bpp's router feature (`rakun-bpp/router`) once front 165 s10's `#[page]` registrations through `compiler.init` land.

[draft/main.bp](draft/main.bp)
