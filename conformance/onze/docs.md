# onze — the joint

onze is the full-stack orchestrator of the botopink ecosystem: the one package that imports
jhonstart (the UI), the `jhonstart-emilia` bridge, emilia (the styles) and rakun (the server)
together, and wires them into an application with an `app/` convention (decision 113). jhonstart
and rakun never import each other, emilia imports nobody, and neither jhonstart nor rakun names
onze: every value that crosses between them is handed across here.

**onze is opt-in.** Nothing in `libs/std`, the shared libraries (`routing`, `actions`,
`validation`) or the compiler references it; a project that does not list it never loads it.

**Requirements.** OTP 28 or later for the server half (the release OTP the botopink CI runs;
the erlang backend's `json` and `maybe` usage needs it) — the replacement for Next's
"Node.js >= 20.9". Node 20 or later for the CLI and the client build (`onze-cli` is commonJS).

## What onze owns

Five things, and nothing that duplicates a rakun or jhonstart definition:

| Piece | Where | What |
|---|---|---|
| `OnzeConfig` | `modules/onze/src/config.bp` | the project configuration `onze.json` holds — `defaultConfig()`, `withPort` / `withDev`, `loadConfig(botopinkJson, onzeJson)` (an unknown key, a wrong kind or a port outside `1..65535` is an `Error` naming the key), `parsePort(text, source)` (a `PORT` / `-p` value), `describeConfig` (the table `onze info` prints) |
| the import alias map | `modules/onze/src/types.bp` | `AliasMap`, `loadAliases(botopinkJson)` (a target that escapes the package root is refused at load, naming the entry), `resolveAlias(map, spec)` (longest prefix first, at a module boundary) |
| the routing-file table | `modules/onze/src/types.bp` | `OnzeProject`, `describeAppFiles(appDir, paths)` — over the `routing` library's `conventions` (`ConventionFile(authoredPath, segment, kind)`, `fileKinds()`, `classify(appDir, path)`; decision 323), which say what an app file is |
| the environment rule | `modules/onze/src/config.bp` | `publicEnvPrefix`, `isPublicEnvName`, `publicEnv` |
| the boot adapter | `modules/onze/src/integration.bp` (both rows) and `modules/onze-server/src/server.bp` (erlang) | the jhonstart half — `bootSite`, `siteRender`, `rakunEntries`, `responseOver`, `chainFor`, `pageInput`, `boot` — and the rakun half: `Onze.run(config)`, `requestData`, `responseFor`, `registerPages`, `registerRoots` |

### `onze.json`

| Key | Default | Meaning |
|---|---|---|
| `name` | `botopink.json`'s `name` | the project name |
| `port` | `3000` | the listener's port |
| `basePath` | `""` | passed to rakun's `App` unchanged — onze does not reimplement prefixing |
| `appDir` | `"app"` | written into rakun as `rakun.appDir`; `"src/app"` is the same mechanism with another string |
| `publicDir` | `"public"` | served verbatim at `/` |
| `outDir` | `".onze"` | the build output |
| `dev` | `false` | development mode |
| `actionsBodyLimit` | `1048576` | bytes; written into rakun as `rakun.actions.bodyLimit` (decision 117) |
| `allowedRedirects` | `[]` | absolute redirect targets jhonstart accepts; handed to `app(allowedRedirects: …)` |
| `lang` | `"en"` | the document's `<html lang>`; handed to `app(lang: …)`, which refuses a value that is not a language tag |

### The import alias map

```json
{ "name": "blog", "alias": { "@/components": "components", "@/lib": "lib" } }
```

`import {PostCard} from "@/components.post_card";` resolves to `components.post_card`, a module of
the app, and is staged as `import {components.post_card.PostCard};` — the compiler's `from` names a
package only (decision 206), and a module of the package is imported by its path inside the
braces, which is also how an app module imports another without an alias. The mechanism is textual
and build-time: `onze-cli`'s staging rewrites the import before the compiler sees it. **The compiler does not know aliases exist**, so an alias is visible through
`onze build` only — a bare `botopink check` on the source tree does not resolve it.

## The four seams

### Seam 1 — the `app/` tree reaches rakun's route table

Not at comptime: `@Decl` carries no source location, so a decorator cannot learn which file it
annotates. The answer is an explicit argument — `#[page("blog/[slug]")]`, `#[layout("blog")]`
(jhonstart front 30), `#[getRoute("api/posts")]` (rakun front 25) — where the argument is the
app-relative directory and the segment grammar is the library `routing`'s. `onze-cli` generates
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

### Seam 2 — a matched route becomes HTML, and the HTML reaches the wire

rakun serves and jhonstart renders; the boot hands each what it needs from the other:

- **to jhonstart**, `bootSite(config, hooks)`: `app(plugins: [emiliaPlugin()], allowedRedirects:
  config.allowedRedirects)`, the two tag fields of `RenderHooks` (`headExtra` / `bodyExtra`, filled
  from `onze-bundler`'s script tags) installed with `setHooks`, and the action wire names installed
  with `setWireNames`;
- **to rakun**, `rakunEntries(config, i18nExclude)`: `rakun.appDir`, `rakun.actions.field`
  (`__bp_action`), `rakun.actions.header` (`X-Bp-Action`), `rakun.actions.bodyLimit` and
  `rakun.i18n.exclude` with `/_onze` appended once — every key rakun reads is a `rakun.*` key
  (decision 115), and neither library spells an action wire name (decision 114);
- **the pages**: `onze-server`'s `registerPages` copies jhonstart's UI table (`uiTable()`) into
  rakun's — every record but a page stored as written (`rkAppStoreEntry`), every page through
  rakun's `page(pattern, render)` with one opaque `PageRenderer`;
- **per request**, that renderer builds the `PageInput` with `pageInput(…)` — the segment chain is
  `chainFor(patterns)`, one `UiSegment` per layout pattern rakun's chain names plus the page's own,
  each as jhonstart's UI registry holds it (`segmentFor`) — builds `RequestData` from rakun's
  `Request` (`requestData`: the method, the path, the parameters rakun matched, the cookies of the
  `cookie` header; rakun's page `Request` enumerates neither its query nor its headers, so those two
  are empty), and wraps rakun's `ChunkWriter` in jhonstart's `Response` (`responseFor` over the
  core's `responseOver`), which maps `status` / `header` / `write` / `close` onto `setStatus` /
  `setHeader` / `write` / `close` one to one:

  ```text
  // one PageRenderer per page pattern — rakun front 23's `page(pattern, render)`
  rakunPage(pattern, { req, out -> renderPage(render, build, table, pattern, req, out) });
  // renderPage: render(pageInput(…), requestData(req), responseFor(out))
  ```

  jhonstart never sees the `ChunkWriter`, and rakun never sees the `Response`;
- **the listener**: `Onze.run(config)` reads `<outDir>/build-id` and `client-manifest.txt` (a missing
  one is a failure naming the file), writes the `rakun.*` entries with rakun's `rkSetProp`, boots
  the jhonstart app with the bundle's head and body tags (`pageRenderHooks`), registers the pages
  and the static roots, installs rakun-web's static entry and chain (`bootWeb`) and the page path
  (`servePages`), and calls `Rakun.run(App(port: config.port, basePath: config.basePath))` —
  `basePath` unchanged.

**Navigation signals never reach onze.** A page, layout or template that calls jhonstart's
`notFound()` or `redirect(url)` is handled inside jhonstart's render (decision 117): before the
first chunk it answers 404 / 307 through the `Response` onze built, after it the late-signal
markup; it also checks the redirect target against the route table and `allowedRedirects`. onze
has no `case` on a signal, imports nothing from `routing`, and hands jhonstart no matcher.

The vocabulary — `PageContext`, `LayoutProps.children` — is jhonstart's; onze does not restate it.

### Seam 3 — emilia's classes reach the HTML

`emilia(tokens)` registers a rule and returns a class name; `flush()` serialises the sheet and
clears it. The moments it is flushed — once into the head after the shell, once per streamed
boundary inside that boundary's fill, nothing left at the end — are jhonstart's `RenderPlugin`
calls, and the `jhonstart-emilia` bridge adapts them (its `payload()` contributes the payload's
`s` key). **emilia's block is written by jhonstart's render through the bridge**; onze's whole part
is registering the bridge in `bootSite`. No onze file calls `flush()` and no onze file defines a
style sink.

Two project-level properties: on erlang the sheet is per BEAM process, so a per-request process
gives per-request style isolation for free; on the JS half there is one process, so **the client
bundle must never call `flush()`** — the `<style>` block is a server artifact, and `onze-bundler`
fails a build whose client graph reaches it.

### Seam 4 — the environment split (a security rule)

> An environment variable is inlinable into the client bundle **only** if its name begins with
> `ONZE_PUBLIC_`, compared case-sensitively. Any other `env.read` reached from a client module
> fails the build, naming the variable and the module that read it. There is no flag, config key
> or annotation that downgrades this to a warning.

`isPublicEnvName("ONZE_PUBLIC_API_URL")` is true; `DATABASE_URL`, `onze_public_x` and
`Onze_Public_Secret` are false — a case-insensitive match is how a secret named
`Onze_Public_Secret` would leak. `publicEnv(names)` drops every name the predicate rejects, so the
list the bundler inlines cannot hold a non-public value even when its caller passes one.

## The client bundle (`onze-bundler`, front 68)

`onze build` walks the client module graph textually (the compiler exposes no module-graph API):
every `import … ;` and `mod …;` line of every `.bp` file, an unreadable import failing the scan with
`file:line`. The roots are the `#[client]` modules the route modules reach on the server side; each
root's closure is the client graph, and every node keeps the chain from the root that pulled it in.

**The build refuses**, with no flag, config key or annotation that relaxes it, a client-graph module
that imports jhonstart's `serverOnly` (or `request` / `cookies` / `headers`), reads a non-`ONZE_PUBLIC_`
variable, reads a variable whose name is not a literal, calls `env.vars()` / `env.write` /
`env.clear`, calls `emilia(…)` with a token list that is not a literal (or a module-level `val` of
one), calls `flush()`, or writes a non-ASCII token list (the two targets' `contentHash` would
disagree). Every refusal of a build is printed, each with its chain:

```
refused: server-only module lib.db reached from client root components.status
  components.status > lib.format > lib.db
build failed: 1 refusal
```

**Chunks.** `shared` (every client module two or more routes reach, plus jhonstart's client
runtime), one `route:<pattern>` chunk per route that reaches a module of its own, and `entry` (the
generated hydration entry). Each is the `__onze_require` registry prelude plus one factory per
module, named `<base>.<contentHash>.js` and served from `/_onze/static/<buildId>/` — immutable, so
two builds of an unchanged tree give the same names and one changed byte changes exactly the
chunks containing it.

**The manifest**, `<outDir>/client-manifest.txt`, read back by the server on every render:

```
V|1|<buildId>
E|entry|/_onze/static/<buildId>/entry.<hash>.js|<hash>|<bytes>
S|shared|/_onze/static/<buildId>/shared.<hash>.js|<hash>|<bytes>
C|route:/blog/[slug]|/_onze/static/<buildId>/r1.<hash>.js|<hash>|<bytes>
H|script:analytics|/a.js|<hash>|<bytes>
R|/blog/[slug]|route:/blog/[slug]
Y|styles|/_onze/static/<buildId>/app.<hash>.css|<hash>|<bytes>
P|ONZE_PUBLIC_API_URL|https://api.example.com
```

A field escapes `%`, `|`, line feed and carriage return (`%25`, `%7C`, `%0A`, `%0D`) and is read
back with std's `percentDecode`. A line of an unknown kind is ignored; a `V` other than `1` is an
error. One parser, both targets.

**The script-tag order**, straddling jhonstart's render:

| # | What | Where | Owner |
|---|---|---|---|
| 1 | every `beforeInteractive` script (`H`), blocking | `<head>` | `headScriptTags` |
| 2 | the document's markup | `<body>` | jhonstart's render |
| 3 | the payload script, `window.__bp0 = …` | end of `<body>` | jhonstart's render, never onze |
| 4 | `shared`, `defer` | after the payload | `scriptTags` |
| 5 | the route chunk, `defer` | after `shared` | `scriptTags` |
| 6 | `entry`, `defer` | last | `scriptTags` |

`bundleRenderHooks(manifest)` wraps the two functions as jhonstart's `RenderHooks`; `bootSite`
installs them. `afterInteractive` and `lazyOnload` scripts are scheduled by the entry, `worker`
scripts started by it (a worker cannot declare `onLoad`).

**The entry** is generated botopink source and spells no `__`-prefixed name: it sets the validation
message source, registers `globals.fill` and `globals.signal` (with `allowedRedirects`), registers
one starter per client component with jhonstart's `registerStarter` (the `globals.starters` table
`hydrate()` reads; each starter decodes the island's props into the component's `#[clientProps]`
record from its source and, before committing the markup, raises on an emilia class the payload's
`s` key does not list — the server's stylesheet has no rule for it), raises on an island or a hole
present on one side of the document/payload only, then calls `hydrate()`, `linkMount()` and
`formMount(actionHeader)`. It imports nothing from `routing` and nothing of rakun.

**The styleMap is evaluated on both backends.** Each literal `emilia(…)` call of the client graph is
compiled into a probe module (`onze_styles`) in the client package and in the server package;
`onze build` runs it under node and under erl — emilia's own `styleRule(tokens, defaultTheme())`,
the rule body hashed with std's `contentHash` — and a call whose class or body hash differs between
the two fails the build (`emilia-hash-split`, naming the token list). The classes the two agree on
are the build's `styles`.

**Dev.** A body edit relinks only the chunks containing the module; an import edit re-walks the
graph; a refusal fails dev with the build's own report; the manifest is written before the push.

## Styles and static files (`onze-assets`, front 69)

**emilia's block is not onze's.** jhonstart's render writes it — into the head after the shell,
into each streamed boundary's fill, and the payload's `s` — through the `jhonstart-emilia`
`RenderPlugin` that `bootSite` registers; the ordering rule is jhonstart front 30's and onze
restates none of it.

**CSS Modules.** `app/blog/blog.module.css` becomes the generated `.onze/styles/app_blog_blog.bp`,
one accessor per class the file defines (a class that begins a selector), renamed
`<file>_<class>_<hash>` (six hex digits of std's `contentHash` of the file) in the selectors only.
The accessors are `pub val`s of a module of the staged app — `import {styles.app_blog_blog.container};
… container`. A class used but not defined is left as written
and reported once; `:global(…)` is not supported; a file containing `</style` is refused.

**The stylesheet.** The global CSS (`app/globals.css`), then every module's rewritten CSS, in one
file, `/_onze/static/<buildId>/app.<hash>.css`, linked in the head (never inlined — it does not
change per request). Its `Y` record goes into the client manifest. `pageRenderHooks(manifest)`
is the head fragment (the stylesheet `<link>`s, then the `beforeInteractive` scripts) and the body
tags as jhonstart's `RenderHooks`.

**Two static roots**, served by rakun-web front 82 (onze serves no file), and no configuration
adds a third:

| Root | Directory | Cache |
|---|---|---|
| `/_onze/static/<buildId>/**` | `<outDir>/static/<buildId>/` | `public, max-age=31536000, immutable` |
| `/**` | `public/` | `no-cache` |

`Onze.run` registers the first with rakun-web's `registerStaticRoot`. The second is not registered
yet: rakun-web answers every request its pattern admits and a miss is a 404, so a `/**` root would
answer every page's URL (decision pending 69-b). Every other directory — `app/`, `src/`,
`content/`, `lib/`, `.onze/` — is unreachable over HTTP.

**Preprocessors.** `preprocess(command, inputPath)` runs the configured command with the input path
and takes its stdout; no command means the file as written; a missing command or a non-zero exit
fails the build naming the command, with its output attached.

## The release (`onze-release`, front 71)

An OTP release is the standalone output — assembled by OTP's own `systools` through std's
`process.run`, not rebar3:

```
<outDir>/release/
  releases/<buildId>/            start.boot, sys.config, vm.args, onze.rel
  lib/<app>-<vsn>/ebin/          every compiled BEAM module, app by app
  erts-<vsn>/                    with includeErts (the default): the runtime itself
  static/<buildId>/              the client chunks and the stylesheet
  public/                        public/, copied verbatim
  prerender/                     prerendered routes and their manifest
  bin/onze                       the boot script `onze start` executes
  BUILD_ID                       one line, the build id
```

**The build id** is derived once — std's `contentHash` over the sorted module hashes and the client
manifest's hash, six hex digits — and must be equal in `BUILD_ID`, the release directory, the
client manifest and the payload's `b`; `verifyBuildId` names the two that disagree. A supplied id
must match `[A-Za-z0-9_-]{1,64}`.

**Configuration is read at boot.** `sys.config` holds defaults only; `vm.args` reads the cookie as
`${RELEASE_COOKIE}` (never a literal); `bin/onze` refuses a build-id mismatch and a missing cookie,
honours `PORT` (default 3000) and `exec`s the VM, so a container's PID 1 is the VM. Packaging
refuses a manifest chunk or stylesheet the build did not produce, and a non-`ONZE_PUBLIC_`
environment value found verbatim in a packaged asset.

**The image** is two stages; the runner copies only the release, runs as the non-root `onze` user,
reads `PORT`; with `includeErts` it is `alpine`, without it an `erlang:` image.

**Shutdown order** (data, `shutdownOrder()`):

1. readiness=false — the load balancer stops sending requests
2. stop-accepting — no new connections
3. drain-renders — in-flight renders, up to the drain timeout
4. drain-after-tasks — the request-scoped `after()` work
5. stop-supervision-tree — and exit

A drain past its timeout exits non-zero with the counts of what was still running. Readiness waits
for the route table, the client manifest and each datasource.

**Static export** writes each prerendered route as `<route>/index.html` beside the static assets and
`public/`, with no boot script and no `releases/`; a route that cannot be prerendered fails the
export naming it.

## Fonts (`onze-assets`, front 52)

`googleFont(family, opts, buildId, outDir)` fetches the Google CSS once at build time (`curl`, a
fixed modern `User-Agent`), keeps the requested subsets, downloads each `woff2` into
`<outDir>/static/<buildId>/fonts/<family>-<weight>.<hash>.woff2` and writes a `.metrics.txt`
sidecar beside it; nothing at request time touches a Google host. The `Font` value carries a class
(`onze-font-inter`), an optional CSS variable, the CSS (`@font-face` per weight × style, the
adjusted fallback, the `:root` variable, the class rule), the preload tags and a `font-family`
string. `fontHead(fonts)` is the preload tags, then one `<style>` of every distinct rule.

**The adjusted fallback** — `size-adjust` (the ratio of the average advances, each over its
`unitsPerEm`), `ascent-override`, `descent-override`, `line-gap-override` (the real face's values
over its `unitsPerEm`) — comes from the committed metrics table. A family missing from the table
with `adjustFontFallback: true` is refused. The table's rows are transcribed, not generated here;
the generator is owed.

**`localFont` without a metrics probe is a degradation, named as one**: the face is emitted with no
adjusted fallback — layout-shift mitigation is off for that family — and the build logs one line
naming the family. It does not guess metrics: a wrong `size-adjust` is worse than none.

## Images (`onze-assets`, front 51)

`Image(props, config, publicDir)` renders an `<img>` whose URLs go through `/_onze/image`, with a
`srcset` (every configured width up to `width` with `sizes`, every width with `fill`, the 1×/2× pair
otherwise — each snapped to a configured width), the box reserved by `width`/`height` or a fill
style, and the loading policy (`priority` → eager, `fetchpriority="high"`; otherwise lazy, async
decoding). The source rules: a `/`-rooted path must stay inside `public/`; an absolute URL must match
`remotePatterns`, **empty by default**; `*.example.com` matches exactly one label; `hostname: "*"` is
refused at config load; `data:` and `file:` URLs are refused. A refused source renders nothing and
is reported, never fetched unoptimized.

**No NIF.** Pixels never enter the VM: the handler spawns one external encoder (`vips` by default,
`magick` accepted) with an argument vector under a deadline the VM keeps (`encoderTimeoutMs`, no
external `timeout` tool); a slow encoder is killed and fails one request. **A missing encoder degrades to pass-through** — the original file is served, and the
handler says optimization is off — because an encoder is an operational dependency; this is the one
place onze degrades instead of failing. Encoded files are keyed by the hash of `src`, `w`, `q`,
`f` and the encoder version, served `public, max-age=31536000, immutable` with that hash as
`ETag`; a width outside `deviceWidths` or a quality outside 1..100 is a 400.

## Social cards (`onze-og`, front 70)

An image route answers an `ImageResponse` — tree, size (1200×630 by default), content type
(`image/png` by default) and faces — never bytes. The card is laid out and emitted as SVG on the BEAM
in pure botopink: a closed style subset (`supportedProperties()`; an unsupported or malformed
declaration is reported and fails the route), a small flexbox (row/column, justify, align, gap,
padding, `%`/`px`, absolute children), text wrapped at spaces over front 52's metrics sidecars (a
word wider than the box overflows; `maxLines` ends with `…`), and `<text>` elements with explicit
font attributes and escaped content.

**The rasterizer decision.** `image/svg+xml` needs no tool. `image/png` goes through a **port** by
default — `resvg` or `rsvg-convert`, spawned with the SVG in a file; a crash kills that process, not
the node. A **NIF** is opt-in and not shipped: a segfault in a native rasterizer takes the whole VM
down and needs a compiled artifact per platform, which the release would then have to package.
With neither, a PNG route fails the build naming the route and the commands — nothing falls back
to SVG under a PNG content type. A card renders once: its key hashes the route, the params, the
SVG, the faces and the size, so a template change invalidates it with no version bump.

## What onze deliberately does not build

| Not built | Why it is not here |
|---|---|
| `reexports.bp` | A consumer writes `import {div, text} from "jhonstart";` because that is where `div` lives. A re-export layer buys one shorter import line for a second name for every symbol in three libraries |
| `PageProps` / `LayoutProps` / `Params` | jhonstart delivers `PageContext` and `LayoutProps`, and `params` is read with `ctxParam(route, name)`. A second vocabulary is a translation layer and a class of bugs |
| `registerPage` / `registerLayout` / `registerAction` | jhonstart's `#[page]` / `#[layout]` decorators fill jhonstart's UI registry, the boot copies it into rakun's table, rakun's `#[serverAction]` registers actions, and `onze-cli` generates the `pub mod` lines that make the decorated modules load |
| `renderDocument` | jhonstart owns the document and the moments the render plugin is called, because only the render knows whether the response is streaming |
| `ActionResponse<S>(state, success, message)` | rakun's `ActionResult` (the library `actions`' envelope) is the action envelope |
| `RouteSegmentConfig(dynamic, revalidate)` | rakun front 60's `SegmentConfig(dynamic, dynamicParams, revalidate, fetchCache)` |

## The commands

`onze build` stages the app twice — the server package (the app, the style modules, `onze_main.bp`,
a dependency on `onze-server`) compiled for erlang and by `erlc` into `<outDir>/server/beam/`, and
the client package (the app and the generated entry) compiled for commonJS — then links the client
chunks, writes the stylesheet, the build id, `static/<buildId>/` and `client-manifest.txt`. The
generated `onze_routes.bp` imports every decorated convention file and registers the undecorated
ones before `main` (decision 140); the generated `onze_main.bp` registers every `#[page]` /
`#[layout]` / `#[template]` / `#[defaultView]` function from the program's catalogue
(`@TypeInfo.all`, decision 216) — a marker registers nothing itself.

`onze start [-p <port>]` compiles nothing: with no `<outDir>/build-id` it exits non-zero naming the
directory; otherwise it runs `erl -noshell -pa <outDir>/server/beam -eval
'<package>@onze_main':main()` from the project root, the server's output in `<outDir>/server.log`.
The port is `-p`, else `PORT`, else `onze.json`'s `port`.

## What is not wired yet

`onze dev` (the build `start` serves, with changed modules reloaded into the running node); the
public root (69-b); `RequestData`'s query and headers (rakun's page `Request` enumerates neither);
the action wire names reach rakun as `rakun.actions.field` / `.header` and nothing in rakun reads
them yet (rakun front 24); prerendering (rakun front 60).
