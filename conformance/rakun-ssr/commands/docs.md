# The commands

> Package: [`rakun-ssr`](../docs.md) · index: [`../../docs.md`](../../docs.md)

`rakun-ssr build` stages the app twice — the server package (the app, the style modules, `onze_main.bp`,
a dependency on `rakun-ssr`) compiled for erlang and by `erlc` into `<outDir>/server/beam/`, and
the client package (the app and the generated entry) compiled for commonJS — then links the client
chunks, writes the stylesheet, the build id, `static/<buildId>/` and `client-manifest.txt`. The
generated `onze_routes.bp` imports every decorated convention file and registers the undecorated
ones before `main` (decision 140); the generated `onze_main.bp` registers every `#[page]` /
`#[layout]` / `#[template]` / `#[defaultView]` function from the program's catalogue
(`@TypeInfo.all`, decision 216) — a marker registers nothing itself.

`rakun-ssr start [-p <port>]` compiles nothing: with no `<outDir>/build-id` it exits non-zero naming the
directory; otherwise it runs `erl -noshell -pa <outDir>/server/beam -eval
'<package>@onze_main':main()` from the project root, the server's output in `<outDir>/server.log`.
The port is `-p`, else `PORT`, else `rakun-ssr.json`'s `port`.
