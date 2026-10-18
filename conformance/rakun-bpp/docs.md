# rakun-bpp — components, hooks and the bpp render

> Package: [`modules/rakun-bpp/`](../../modules/rakun-bpp/) · index: [`../docs.md`](../docs.md) · notes: [`../../modules/rakun-bpp/AGENTS.md`](../../modules/rakun-bpp/AGENTS.md)

A React/Next-style UI framework written in botopink, on the language's own
primitives: the `Element` tree and its builders, the forty-six HTML
constructors, synchronous `renderToString`, the
`state`/`effect`/`memo`/`ref`/`reducer` family, the `` html @`…` `` authoring
DSL, the router, server components, client navigation, the client boundary,
streaming, forms, error boundaries and metadata. What is still gated is the
*client* half — the delegated click handler, prefetch, link status and the
reconciler driver — and it waits on `rakun-ssr`'s generated bundle and
`rakun-app`'s route-kind table, not on a language gap (see **V1 limits**).

## Features

Each feature is a directory, `conformance/rakun-bpp/<feature>/`: its `docs.md`
says what the feature does and links the cells beside it.

| Feature | What it shows |
|---|---|
| [Components](components/docs.md) | loading the package, the component model, the DOM builders, the element surface, the client runtime |
| [Hooks](hooks/docs.md) | the five nouns and a custom hook |
| [The `html` DSL](html-dsl/docs.md) | `` html @`…` `` and its holes |
| [The router](router/docs.md) | the router snapshot, its cells and the six hooks |
| [Server components](server-components/docs.md) | `RequestData`, the server-component and loader conventions |
| [Client navigation](client-navigation/docs.md) | `link` props, the anchor, prefetch, remounting |
| [The client boundary](client-boundary/docs.md) | `#[client]`, `#[clientProps]`, islands, `serverSlot`, `serverOnly` |
| [Render and streaming](streaming/docs.md) | the walker, boundaries and fills, the response, the payload |
| [Forms](forms/docs.md) | a form bound to a server action |
| [Error boundaries](error-boundaries/docs.md) | a boundary catching a render failure |
| [Metadata](metadata/docs.md) | merging page metadata |

## App layer (Next-style) — declared, host-bound

- `Link` is no longer declared: see *Client navigation* above. `link.bp` and
  `reconcile.bp` are compiled and pure; what is still missing is the **browser
  half** — front 68's generated bundle and front 60's route-kind table.
  The router itself is no longer declared either: see *The router* above.
- The server context is no longer declared either: see *Server components*
  above. `server.bp` is compiled, with both host halves shipped.
- File routing (`app/`, `page.bp`, `layout.bp`, `[id]`) is a **convention** (V1),
  wired manually until a CLI/build step lands.
- `renderToString(app)` (SSR, real `.bp`) / client `mount` (host).

## V1 limits

- **Implemented now** (`element.bp` + `elements.bp` + `hooks.bp`, and `html.bp` in `rakun-bpp`, compiled +
  `test {}`-checked): the `Element` type, builders (`Children` args, list-form
  render), the element surface (`el`/`voidEl`, `isVoidTag`/`isRawTextTag` and
  thirty-eight further tag constructors), a synchronous `renderToString`, the
  `state`/`effect`/`memo`/`ref`/`reducer` hook family (real SSR bodies), the
  route snapshot and its six hooks and six navigation verbs (`router.bp`, with
  both host halves), the request record, its four accessors, `request()` and
  the server-component convention (`server.bp`, with both host halves), the
  render-time half of client navigation — `Link`, `LinkProps` and its five
  `with*` helpers, `prefetchMode`, `layoutKey`, `layoutKeys`, `sharedDepth`,
  `linkStatusOf` (`link.bp` + `reconcile.bp` in `rakun-bpp`, pure, no host cell), the client
  boundary — `#[client]`, `#[clientProps]` and the four comptime refusals
  around them, `islandId`/`islandAttrOf`/`islandAttr`, `Island`, `clientMount`,
  `islandEntry`, `propsOf`, `serverSlotAttr`/`serverSlot` and the `serverOnly`
  poison pill (`client.bp`, pure, no host cell) — and the
  `` html @`…` `` markup DSL
  (comptime expansion to the builder pipeline). Author trees as `div([…])` or as
  `` html @`…` ``.
- **Gated / declarative** (each a generic core gap, none rakun-bpp-specific):
  - (closed) `use request()`: `request()` is `fn … -> @Component<RequestData>` (botopink decisions 104/128), activated inside a
    `@Component<Element>` server component.
    The server surface itself is no longer gated: `server.bp` is compiled with
    both host halves shipped (see *Server components*). `Link` and the form
    controls are no longer gated on an attribute slot either: `Element` carries
    `attrs`, and `elements.bp` ships
    `form`/`input`/`button`/`label`/`select`/`textarea`; `Link` is front 27's
    `src/link.bp`, compiled and pure — see *Client navigation*;
  - the **browser half** of client navigation. `link.bp` and `reconcile.bp`
    ship the render-time half; the four `#[@external(.Node(…))]` cells
    (`__jhLinkMount`, `__jhLinkPrefetch`, `__jhLinkStatus`,
    `__jhLinkRouteKind`), the `linkStatus()` hook and the transition driver
    `reconcile(current, target)` wait on front 68's generated bundle and front
    60's route-kind table, and are not stubbed;
  - the **build-time half** of the client boundary. `client.bp` ships the
    markers, the island and the hole; the two `#[@external(.Node(…))]` cells
    (`hydrate`, `islandProps`), the `propsFor(name)` wrapper over the second,
    and every "may not" rule — no `serverOnly` in the client graph, no request
    scope in a client module, a server component as a child and never a prop —
    wait on **front 68**'s walk over the module graph and its generated bundle,
    and are not stubbed. **Today the boundary is a vocabulary with four
    comptime refusals, not a guarantee**: a secret read on the server still
    reaches the browser if it is written into an island's props;
  - parallel loading. `@Task` is eager on the erlang row, so independent
    loaders awaited in sequence cost the sum of their round trips; the
    spawn-and-gather over unstarted tasks is front 02's and rakun-bpp ships no
    second answer;
  - HTML escaping. `renderToString` escapes nothing and front 01's
    `escape.html` / `escape.attribute` do not exist yet;
  - the trailing-lambda children sugar (`div { … }`) and lone-child / `string`
    `Children` *rendering* (type-checks today; render needs normalization).
