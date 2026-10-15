# Render and streaming

> Package: [`rakun-bpp`](../docs.md) · index: [`../../docs.md`](../../docs.md)

Front 30. rakun-bpp writes the HTML (decision 113): the escaping walker, the
document, the payload, the streamed fills and the navigation-signal
translation are here, and rakun / rakun-ssr hand values in.

## The walker

`renderNode(e)` is what every path renders through — never `renderToString`:
`#text` through std's `escape.html`, every attribute value through
`escape.attribute`, a void tag (front 94's `isVoidTag`) with no closing tag,
`script` / `style` (front 94's `isRawTextTag`) verbatim — a body holding
`</script` / `</style` in any case **fails the render**, never escaped — and
`raw(html)`, the one element written verbatim. `shellHtml(page)` is the page
with every boundary showing its fallback.

## Boundaries and fills

```text
pub type Boundary(id: string, fallback: Element, child: fn() -> @Component<Element>)
pub fn Suspense(b: Boundary) -> Element      // <div data-jh-h="h1">fallback</div>
pub fn holeId(index: i32) -> string          // "h1"
pub fn resolve(b: Boundary) -> @Task<Chunk>  // awaits the child once
pub fn fillHtml(c: Chunk, css: string) -> string
//   <template data-jh-f="h1">css…markup…</template><script>__bp1("h1")</script>
```

{suspense_boundary/src/main.bp}

The child is an **unstarted thunk**: `@Task` is eager on erlang, so a started
Task would already have run. `Suspense` registers the boundary with the render
(an `Element` has nowhere to carry the thunk). `renderStream` hands each
boundary's thunk to its own process and writes the fills in **completion**
order as they report; `render` resolves them all first and writes one
document. On erlang the render's request and route are re-entered in each
boundary's process, and the plugins' `chunk(id)` runs there too, so a
per-process stylesheet sees what the boundary registered.

## `compose`, the UI conventions and `UiSegment`

`compose(chain, route, page)` wraps the page per segment, root-first:
`layout > template > error > loading > not-found > page`. Layouts **run
first** (each with a placeholder child, substituted afterwards), so a layout's
`redirect` means the page never runs. Each layout gets its `selected` depth
through the route snapshot; a template wrapper carries
`data-jh-t="<pattern>#<n>"`, fresh per render; `error` catches below it,
`loading` makes everything below it a streamed boundary, `not-found` wraps
below it in `data-jh-n` and is the tree a not-found signal renders.

`UiSegment` is one segment's conventions (`segment(pattern)` +
`withLayout`/`withTemplate`/`withError`/`withLoading`/`withNotFound`, or
`segmentFor(pattern)` from the registry). It is not `Segment`: that name is
the library `routing`'s, and a consumer's flat `import {Segment} from
"rakun-bpp"` would be ambiguous.

| File in `app/` | Marker | Signature it accepts |
|---|---|---|
| `layout.bp` | `#[layout(seg)]` | `fn(props: LayoutProps) -> @Component<Element>` |
| `template.bp` | `#[template(seg)]` | `fn(props: LayoutProps) -> @Component<Element>` |
| `page.bp` | `#[page(seg)]` | `fn(route: PageContext) -> @Component<Element>` (+ `<name>Params(route)`) |
| `default.bp` | `#[defaultView(seg)]` | `fn(props: LayoutProps) -> Element` |

`#[page]`, `#[layout]` and `#[template]` refuse any other return, naming the
function and the form it needs. A marker registers nothing itself: it records
its segment as meta (`seg`), and the program's entry point registers every
marked function once, from the program's catalogue:

```text
val __jhRoutes = jhRegisterRoutes(
    @TypeInfo.all(with: page),
    @TypeInfo.all(with: layout),
    @TypeInfo.all(with: template),
    @TypeInfo.all(with: defaultView),
);
```

Layouts register first, then templates, pages and default views, each in the
catalogue's order (module path, then declaration order). The module holding
that line is imported by nobody — rakun-ssr's generated `onze_main.bp`, or a test
file. The application site imports what `#[page]`'s accessor emits
(`PageContext`, `ctxParam`, `ctxRest`). `uiTable()` answers the registry as
contract-1 lines; rakun-ssr copies it into rakun's table.

## The response and the two entries

```text
pub type Response(status: fn(code: i32) -> void, header: fn(name: string, value: string) -> void,
                  write: fn(chunk: string) -> @Task<void>, close: fn() -> @Task<void>)
pub type PageInput(build, pathname, pattern, params, query, table, actions,
                   chain: Array<UiSegment>, page: fn() -> @Component<Element>,
                   metadata: Array<Metadata>, viewports: Array<Viewport>)
pub fn app(plugins: Array<RenderPlugin>, allowedRedirects: string[] = [], lang: string = "en") -> App
site.render(input, req, res) -> @Task<@Result<void, string>>
site.renderStream(input, req, res) -> @Task<@Result<void, string>>
```

`lang` is the document's `<html lang>`: letters, digits and `-`, starting with
a letter (`isLangTag`); `app` refuses anything else, naming it.

The render enters `req` (front 28) and leaves it, writes `status(200)` and the
content type before its first `write`, and calls `close()` exactly once on
every path; `status` / `header` after the first write fail the render. It
answers `Ok` for a closed response — normal or signalled — and `Error(message)`
for a failed render. `metadata` / `viewports` are the segments' resolved
exports, merged root-first (front 32).

| A signal raised | The render writes |
|---|---|
| `redirect(to)` before the first chunk | `status(307)`, `header("location", to)`, `close()` |
| `notFound()` before the first chunk | `status(404)`, a document whose body is the nearest not-found boundary |
| either, after the first chunk | `<template data-jh-g="redirect" data-jh-to="…">` / `<template data-jh-g="not-found">…` + `<script>__bp2()</script>` as the last chunk; status stays 200 |

A redirect target is checked the same way everywhere: a relative target must be
matched by `routing`'s `matchPath` in `PageInput.table`, an absolute one listed
in `app(allowedRedirects: […])` (empty by default); anything else fails the
render with no status, no `location` and no markup.

## The payload and the globals

One `<script>window.__bp0 = {…}</script>`, last in `<body>` before
`RenderHooks.bodyExtra`: keys `v` (1), `b`, `p`, `r`, `m`, `q`, `t`, `i`, `a`,
`h`, `d`, then each plugin's key. Written with std's `json.quote` /
`json.array` / `json.object` and passed through `escape.scriptJson`, so
`</script` cannot appear in it. Island ids are `i0`, `i1`, … in render order
(`mountIsland`, through front 29's `islandEntry`).

The four browser globals are aliases from `globals.bp`'s registry —
`globals.payload == "__bp0"`, `.fill == "__bp1"`, `.signal == "__bp2"`,
`.starters == "__bp3"` (the island starter table, front 29), the fields of one
module-level `pub val globals` — and no other file spells them. `readPayload(name)` decodes the payload text with
std's `json.decode`; `registerFill` / `registerSignal` install `render.mjs`'s
fill and signal functions (called only by rakun-ssr front 68's entry).

## `RenderPlugin`

```text
pub type RenderPlugin(name: string, head: fn() -> @Task<string>, chunk: fn(holeId: string) -> @Task<string>,
                      close: fn() -> @Task<@Result<void, string>>, payload: fn() -> @Task<Array<#(string, Json)>>)
```

A record of async functions (an array of two different behavior implementors
does not type). `head` once, into `<head>`; `chunk(id)` per streamed boundary,
first inside its fill; `close` at the end — an `Error` fails the render;
`payload` once, last — a render key or a key two plugins give fails the render,
naming them. The `rakun-stylesheet` member is the one plugin in this workspace.
