# Decision 130 — A failing render carries `E = string`; the writers stay infallible

Three page renderers registered with `rakun-app`'s `page`, each a lambda over the request and the `ChunkWriter` rakun hands it, each answering `Task<Result<void, string>>`. `posts` writes its heading with `writeTo` — a `Task<void>`, awaited with nothing to propagate — and then either finishes (`return;`, the `Ok`) or answers `Error("the post store is down: secret-dsn")`. `unavailable` answers the `Error` before writing anything.

The dispatch reads the `Error` exactly as it reads a raise of the renderer. `/ok` answers `200` and both chunks. `/early` answers `500`, and its body does not contain `secret-dsn`: the message goes to the log under a correlation digest, never on the wire. `/late` had already written its heading, so the response it began is closed: `200` and the one chunk, `<h1>posts</h1>`.

Misuse of the writer is not a value: a write after `close`, or a status or header set after the first write, raises.

Cells of this repository that prove it: none yet. `modules/rakun-app/test/ssr_test.bp` drives the same three cases (an `Error` before and after the first chunk, the message kept off the wire); the cells come with rakun front 23 step 1's conformance.

[draft/main.bp](draft/main.bp)
