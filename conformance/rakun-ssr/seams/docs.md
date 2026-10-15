# The four seams

> Package: [`rakun-ssr`](../docs.md) · index: [`../../docs.md`](../../docs.md)

## Seam 1 — the `app/` tree reaches rakun's route table

Not at comptime: `@Decl` carries no source location, so a decorator cannot learn which file it
annotates. The answer is an explicit argument — `#[page("blog/[slug]")]`, `#[layout("blog")]`
(rakun-bpp front 30), `#[getRoute("api/posts")]` (rakun front 25) — where the argument is the
app-relative directory and the segment grammar is the library `routing`'s. `rakun-ssr` generates
the `pub mod` lines from the tree and **fails the scan when a file's location and its decorator
argument disagree**. `routing`'s `conventions.classify(appDir, path)` answers a
`ConventionFile`; its `segment` is the value it compares:

| File | `segment` | `kind` |
|---|---|---|
| `app/page.bp` | `""` | `page` |
| `app/blog/[slug]/page.bp` | `blog/[slug]` | `page` |
| `app/(marketing)/about/page.bp` | `(marketing)/about` — the group is in the segment, absent from the route pattern | `page` |
| `app/api/posts/route.bp` | `api/posts` | `route` |
| `app/_components/card.bp` | — a `_private` folder opts out with everything below it | not an app file |

The eight kinds are exactly `page`, `layout`, `template`, `default`, `loading`, `error`,
`not-found` and `route`.

## Seam 2 — a matched route becomes HTML, and the HTML reaches the wire

rakun serves and rakun-bpp renders; the boot hands each what it needs from the other:

- **to rakun-bpp**, `bootSite(config, hooks)`: `app(plugins: [emiliaPlugin()], allowedRedirects:
  config.allowedRedirects)`, the two tag fields of `RenderHooks` (`headExtra` / `bodyExtra`, filled
  from `rakun-ssr`'s script tags) installed with `setHooks`, and the action wire names installed
  with `setWireNames`;
- **to rakun**, `rakunEntries(config, i18nExclude)`: `rakun.appDir`, `rakun.actions.field`
  (`__bp_action`), `rakun.actions.header` (`X-Bp-Action`), `rakun.actions.bodyLimit` and
  `rakun.i18n.exclude` with `/_onze` appended once — every key rakun reads is a `rakun.*` key
  (decision 115), and neither library spells an action wire name (decision 114);
- **the pages**: `rakun-ssr`'s `registerPages` copies rakun-bpp's UI table (`uiTable()`) into
  rakun's — every record but a page stored as written (`rkAppStoreEntry`), every page through
  rakun's `page(pattern, render)` with one opaque `PageRenderer`;
- **per request**, that renderer builds the `PageInput` with `pageInput(…)` — the segment chain is
  `chainFor(patterns)`, one `UiSegment` per layout pattern rakun's chain names plus the page's own,
  each as rakun-bpp's UI registry holds it (`segmentFor`) — builds `RequestData` from rakun's
  `Request` (`requestData`: the method, the path, the parameters rakun matched, the cookies of the
  `cookie` header; rakun's page `Request` enumerates neither its query nor its headers, so those two
  are empty), and wraps rakun's `ChunkWriter` in rakun-bpp's `Response` (`responseFor` over the
  core's `responseOver`), which maps `status` / `header` / `write` / `close` onto `setStatus` /
  `setHeader` / `write` / `close` one to one:

  ```text
  // one PageRenderer per page pattern — rakun front 23's `page(pattern, render)`
  rakunPage(pattern, { req, out -> renderPage(render, build, table, pattern, req, out) });
  // renderPage: render(pageInput(…), requestData(req), responseFor(out))
  ```

  rakun-bpp never sees the `ChunkWriter`, and rakun never sees the `Response`;
- **the listener**: `Onze.run(config)` reads `<outDir>/build-id` and `client-manifest.txt` (a missing
  one is a failure naming the file), writes the `rakun.*` entries with rakun's `rkSetProp`, boots
  the rakun-bpp app with the bundle's head and body tags (`pageRenderHooks`), registers the pages
  and the static roots, installs rakun-service's static entry and chain (`bootWeb`) and the page path
  (`servePages`), and calls `Rakun.run(App(port: config.port, basePath: config.basePath))` —
  `basePath` unchanged.

**Navigation signals never reach rakun-ssr.** A page, layout or template that calls rakun-bpp's
`notFound()` or `redirect(url)` is handled inside rakun-bpp's render (decision 117): before the
first chunk it answers 404 / 307 through the `Response` rakun-ssr built, after it the late-signal
markup; it also checks the redirect target against the route table and `allowedRedirects`. rakun-ssr
has no `case` on a signal, imports nothing from `routing`, and hands rakun-bpp no matcher.

The vocabulary — `PageContext`, `LayoutProps.children` — is rakun-bpp's; rakun-ssr does not restate it.

## Seam 3 — rakun-stylesheet's classes reach the HTML

`emilia(tokens)` registers a rule and returns a class name; `flush()` serialises the sheet and
clears it. The moments it is flushed — once into the head after the shell, once per streamed
boundary inside that boundary's fill, nothing left at the end — are rakun-bpp's `RenderPlugin`
calls, and the `rakun-stylesheet` bridge adapts them (its `payload()` contributes the payload's
`s` key). **rakun-stylesheet's block is written by rakun-bpp's render through the bridge**; rakun-ssr's whole part
is registering the bridge in `bootSite`. No rakun-ssr file calls `flush()` and no rakun-ssr file defines a
style sink.

Two project-level properties: on erlang the sheet is per BEAM process, so a per-request process
gives per-request style isolation for free; on the JS half there is one process, so **the client
bundle must never call `flush()`** — the `<style>` block is a server artifact, and `rakun-ssr`
fails a build whose client graph reaches it.

## Seam 4 — the environment split (a security rule)

> An environment variable is inlinable into the client bundle **only** if its name begins with
> `ONZE_PUBLIC_`, compared case-sensitively. Any other `env.read` reached from a client module
> fails the build, naming the variable and the module that read it. There is no flag, config key
> or annotation that downgrades this to a warning.

`isPublicEnvName("ONZE_PUBLIC_API_URL")` is true; `DATABASE_URL`, `onze_public_x` and
`Onze_Public_Secret` are false — a case-insensitive match is how a secret named
`Onze_Public_Secret` would leak. `publicEnv(names)` drops every name the predicate rejects, so the
list the bundler inlines cannot hold a non-public value even when its caller passes one.
