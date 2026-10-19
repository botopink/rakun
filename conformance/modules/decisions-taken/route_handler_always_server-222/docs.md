# Decision 222 — A route handler is always server: a `#[route]` handler (`route.bp`, answering a `Response`, every method, `GET` included

The example puts a page and a route handler side by side in one `app/` tree. `Posts` is a
`#[page("posts")]` whose body reads nothing per request, so the build prerenders it once. `now` is
a `#[getRoute("api/now")]` handler: it answers a `HandlerResponse` with the clock's reading, and
because a handler is always server, that reading is taken on every request — the build never calls
`now`, never writes its answer to a file, and nothing it reaches (`clock.nowMillis()`, the
request) is evaluated while building, even though the method is `GET` and the body has no
parameter it depends on.

`main` starts the app and dispatches two requests to `/api/now` through `serveApp()`'s table; the
two answers carry two readings, which a prerendered response could not. Prerendering stays
`#[page]`'s alone: a handler has no `revalidate`, no `paths`, no static export.

Proving cells: none in this repository yet; rakun-app has no `conformance/` feature of its own
(its `docs.md` lists file routing and SSR with no cells), and they come with front 117 step 4 and
`04-rakun/22`.

[draft/main.bp](draft/main.bp)
