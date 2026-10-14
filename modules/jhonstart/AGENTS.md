# jhonstart

> Package `jhonstart` of the rakun workspace — `repository/rakun/modules/jhonstart/` · workspace rules: [`../../AGENTS.md`](../../AGENTS.md) · cells: `../../conformance/jhonstart/`

botopink's **React/Next-style** UI framework, written *in* botopink on the
language's own primitives — **no jhonstart-specific compiler features**.
Components are functions returning `@Component<Element>`; hooks are nouns
(`state`, `router` — never `useState`) returning the `@Component<_>`
capability, activated by the `use` keyword (decision 88 of 1.0.10-beta:
`use f(x)` lowers to `f(x)` on every backend); a server component that only
loads data is `fn … -> @Task<Element>` (the return type is the effect — botopink
decisions 118–128, front 24; the `#[@<effect>]` annotations and `@Future` left, and
`*fn` before them); the JSX-like
`html """…"""` DSL reuses `expr-templates` (`@Expr<Element>`), expanding markup
to the builder pipeline at comptime. The compiler is **unaware** of jhonstart (hard rule + `grep -riE
"rakun|jhonstart" modules/compiler-core/src` gate); the framework is a pure
client, reached with `from "jhonstart"`, never embedded.

The UI **core + hooks + the element surface + the `html` markup DSL are real
botopink** (`modules/jhonstart/src/{element,hooks,elements}.bp` in the core
member's compiled set, `modules/jhonstart-html/src/html.bp` in the
`jhonstart-html` member's — front 95 cut the DSL out of the core): an
`Element` tree, builders, a synchronous SSR renderer, the hook family, and the
`html """…"""` comptime expander — no host intrinsics, no async. Since fronts 26
and 28 there is **no `.d.bp` module left**: the route snapshot and the request
are compiled and each ships its own host half on both rows
(`router_runtime.mjs` / `sidecars/jhonstart_router.erl`, `server_runtime.mjs` /
`sidecars/jhonstart_server.erl`). Client navigation is compiled too since
front 27 (`link.bp`, `reconcile.bp`, in the `jhonstart-link` member since front
95's relocation): the render-time half is pure, and the browser half —
`linkMount`, `linkPrefetch`, `linkRouteKind`, `linkStatus` — sits over four
dual-target cells whose erlang twins answer the server's idle truth (until
`linkStatus` becomes `#[clientOnly]`, decision 363); the transition driver
(`applyTransition` over the entry's `DomOps`) is pure and landed, its adoption
by onze's entry and front 60's route-kind flag are still to come. The
server/client BOUNDARY is compiled since front 29 (`client.bp`): `#[client]` and
`#[clientProps]` are comptime markers with four refusals, and the island, the
hole and the poison pill are ordinary `.bp`; what ENFORCES the boundary over the
module graph is front 68's and is not stubbed either. Nothing is embedded
into the prelude.

## Tree

> **In the rakun workspace** (front 165 s1) this package is `modules/jhonstart/`, and the tree below is the one it had as a repository of its own: its former `modules/*` are siblings in rakun's `modules/`, its cells are `conformance/jhonstart/`, its examples `examples/jhonstart/`, its refusals `refusals/jhonstart/`; the root manifest, `scripts/` (one gate, one hook), `.github/` and `.gitignore` are rakun's — read the tree for the package's own layout, never for those.

`repository/jhonstart/botopink.json` is a **workspace**, not a package (decision
75 of 1.0.10-beta): it carries `name`, `version`, `description`, `targets` and
`"workspaces": ["modules/*", "examples/*"]`, and `src` / `entry` / `files` /
`dependencies` are located errors there. It compiles nothing, ships nothing and
answers no import — `botopink build/check/run/test` at the root is the refusal
that names the members. The library is the member `modules/jhonstart/`, which
is what `from "jhonstart"` resolves to.

```text
repository/jhonstart/
├── AGENTS.md          ← you are here
├── botopink.json      ← WORKSPACE: name, version, description, targets [commonJS, erlang], workspaces [modules/*, examples/*]
├── conformance/       ← the reference and its examples (decision 463): `docs.md` (the user-facing reference) and `modules/<example>/` cells run by `botopink cell check conformance/`; `conformance/modules/botopink.json` is a workspace whose members are the cells (`"workspaces": ["*"]`, decision 512 of the compiler): it declares what every cell shares — jhonstart as the path dependency `../../modules/jhonstart`, the targets commonJS, erlang and beam, the version — so a cell's own `botopink.json` holds its name and the members it adds beside jhonstart (`jhonstart-html`, `-forms`, `-link`), and the cells' dependencies share one code cache, `conformance/modules/.botopinkbuild/cache/` (decision 509; `botopink cell check --cold` reads none of it).
├── modules/
│   ├── jhonstart/     ← CORE — what `from "jhonstart"` gives a consumer
│   │   ├── botopink.json  ← name jhonstart, src src/, entry root.bp, target commonJS, files [root.bp, element.bp, hooks.bp, router.bp, server.bp, globals.bp, client.bp, error_boundary.bp, metadata.bp, elements.bp, suspense.bp, plugin.bp, routes.bp, styled_sheet.bp, render.bp, streaming.bp, client_app.bp, client_runtime.bp, html_attrs.bp, node.bp, prelude.bp], dependencies { actions, routing, styled: git `feat` } (DEPENDENCY order — a dependent loads the files in this order, so a module comes after every module it imports; `root.bp` keeps front-number order)
│   │   ├── src/
│   │   │   ├── AGENTS.md
│   │   │   ├── root.bp        ← module-tree root: `pub mod element; pub mod hooks; pub mod router; pub mod server; pub mod client; pub mod suspense; pub mod streaming; pub mod render; pub mod plugin; pub mod globals; pub mod routes; pub mod error_boundary; pub mod metadata; pub mod elements; pub mod html_attrs; pub mod node; pub mod prelude; mod client_runtime;`
│   │   │   ├── element.bp     ← COMPILED CORE: `type ElementBase()` (the empty-record phantom decision 128's wrapper named, until `ElementContext` retires it — 354 (7)) + type Element (`implement @Renderable`) + `pub type View = @Component<Element>` (decision 276, front 118) + builders (Children) + renderToString + test {}
│   │   │   ├── node.bp        ← COMPILED (front 118), PURE: `pub type Node = string | i32 | i64 | f32 | f64 | bool | Element | Element[]` — what a template hole and a `children` field hold (decisions 191, 223)
│   │   │   ├── hooks.bp       ← COMPILED: State<T> + state/effect/memo/ref/reducer (@Component<_>, pure server-pass bodies) + test {} (imports `Element`)
│   │   │   ├── prelude.bp     ← COMPILED (front 118): the `.bpp` prelude (decision 270) — `import` items of the core's own modules only (`Element`, `ElementBase`, `View`, `Node`, `raw`, `el`, every builder; `timeTag as time`), and the marker `#[bpp.htmlPrelude] pub val prelude = bpp.Prelude();` by which the toolchain finds it (decision 361, std's `bpp`)
│   │   │   ├── elements.bp    ← COMPILED: the element surface (front 94) — `el`/`voidEl`, `isVoidTag`/`isRawTextTag`, and the tags `element.bp` does not declare
│   │   │   ├── client_runtime.bp  ← COMPILED: the `clientRender` `#[@External.Node("./client_runtime.mjs", "render")]` cell — ships the sidecar
│   │   │   ├── client_runtime.mjs ← HOST: the client build's hooks (state/effect/memo/ref/reducer + render) over jhonstart's own re-render loop
│   │   │   ├── router.bp      ← COMPILED: the route snapshot (front 26) — `RouterState`, `pairValue`, `snapshot`/`fill`, `navigationFor`/`applySignal` (the envelope's `n`, through `routing`), `resolveRoute` (`routing`'s `matchPath` over the payload's `t`)
│   │   │   ├── client_app.bp  ← COMPILED (front 26 Step 6): `ClientApp` / `clientApp(routes, mount, allowedRedirects).start()` — a client-only app over `routing`'s matcher, front 30's `compose` and the one browser write `__jhMount`; `notFound` / `redirect` handled as the server render handles them. Host halves `client_app.mjs` / `sidecars/jhonstart_client_app.erl` (a module store when there is no `window`)
│   │   │   ├── router_runtime.mjs ← HOST (js): the router's store and the History API half of `navigate`
│   │   │   ├── sidecars/
│   │   │   │   ├── jhonstart_router.erl ← HOST (BEAM): the same cells over the calling process's dictionary. NOT a `files` entry — `shipErlSidecars` finds it under the package's `src/sidecars/`
│   │   │   │   └── jhonstart_server.erl ← HOST (BEAM): the request's six cells + `fill/6`, same process dictionary, same non-`files` discovery
│   │   │   ├── server.bp      ← COMPILED: the request (front 28) — `RequestData` + four accessors, `request`/`enterRequest`/`leaveRequest`/`cookies`/`headers`, `renderServerComponent`
│   │   │   ├── server_runtime.mjs ← HOST (js): the request store, the twin of `jhonstart_server.erl` cell for cell
│   │   │   ├── html_attrs.bp  ← COMPILED (front 48 of the CSS track), PURE: `classAttr` (the `class` pair spelled once), `withAttrs` (append, base first — `renderToString` writes attrs in array order), `attrValue` (the last pair of a name, `""` when absent). Imports only `element` and names no styling library: the styling side hands over a `#(string, string)` pair and merges its own class names
│   │   │   ├── client.bp      ← COMPILED (front 29): `#[client]` + `#[clientProps]` (comptime markers, four refusals), `islandId`/`islandAttrOf`/`islandAttr` (decision 77 — the ONE spelling of `data-jh-i`), `Island` + `clientMount` + `islandEntry` + `propsOf`, `serverSlotAttr`/`serverSlot`, `serverOnly`, `hydrate()` / `propsFor(name)` and the starter table (`registerStarter`, `registerRouteStarters`, `registeredStarters`, `registeredRouteStarters` into `globals.starters`) over dual-target cells (`island_runtime.mjs` / `sidecars/jhonstart_island.erl`). The graph walk is front 68's
│   │   │   ├── suspense.bp    ← COMPILED (front 30): `Boundary(id, fallback, child: fn() -> @Component<…>)` (an UNSTARTED thunk), `Suspense` (the `data-jh-h` hole; registers the boundary with the render), `holeId`
│   │   │   ├── styled_sheet.bp ← COMPILED (front 119 step 1, decisions 352, 354 (7), 361): the render's `styled` sheet — `renderSheet()` (the `StyledSheet` `compose` provides as `styled`'s `StyledContext`, writing to layer `styled`), `renderedStyles()`, `styledLayer()`; the `Sheet` value kept in the per-render state (`render.mjs` / `jhonstart_render.erl`), so a component rendered twenty times is written once
│   │   │   ├── render.bp      ← COMPILED (front 30): `renderNode` (the escaping, void-aware walker over std `escape`), `raw`, `shellHtml`, `mountIsland` (i0, i1 … through front 29's `islandAttr`), `compose` (layout > template > error > loading > not-found > page; layouts run first; the root of a page render, it provides `StyledContext`), `Payload`/`writePayload` (std `json` + `escape.scriptJson`), `RenderHooks`/`setHooks`, the document
│   │   │   ├── streaming.bp   ← COMPILED (front 30): `Chunk`/`resolve`/`fillHtml`, the late-signal markup, `Response` + `guarded`, `PageInput`, `App`/`app` with `render` / `renderStream` (→ `@Task<@Result<void, string>>`), the signal translation and the redirect-target check
│   │   │   ├── plugin.bp      ← COMPILED (front 30): `RenderPlugin(name, head, chunk, close, payload)` — a record of async functions, called in `app`'s order
│   │   │   ├── globals.bp     ← COMPILED (front 30): the registry `payload, fill, signal, starters` → `__bp0/1/2/3`, the fields of `pub val globals`; `readPayload` (std `json.decode`), `registerFill`, `registerSignal`
│   │   │   ├── routes.bp      ← COMPILED (front 30): `#[page]`/`#[layout]`/`#[template]`/`#[defaultView]`, `PageContext`, `LayoutProps`, the UI registry (`jhPage`… `uiTable()`; the markers record meta `seg` and the entry point registers them with `jhRegisterRoutes(@TypeInfo.all(with: page), …)`, decision 216); `#[page]`'s parameter accessor reads a segment's names from `routing`'s `segment.paramNamesOf` and which of them is a list from `parseSegment` / `kindName` (front 102), `UiSegment` + `segment`/`with*`/`segmentFor`
│   │   │   ├── render.mjs     ← HOST (js): per-render state + `eachCompleted`, and the browser half (fill / signal functions, payload text)
│   │   │   ├── routes.mjs     ← HOST (js): the UI registry
│   │   │   ├── sidecars/jhonstart_render.erl ← HOST (BEAM): per-render state in the process dictionary, hooks in `persistent_term`, `each_completed/2` (one process per boundary, values handed back in completion order)
│   │   │   ├── sidecars/jhonstart_routes.erl ← HOST (BEAM): the UI registry, an ETS table with an owner process
│   │   │   ├── error_boundary.bp ← COMPILED (front 31): `ErrorInfo`/`ErrorBoundary`, `renderBoundary`/`renderBoundaryChecked`/`catchError`, the digest (std `hash.contentHash`), `notFound`/`redirect` raising `routing`'s `nav:` reasons, `isSignal`
│   │   │   ├── metadata.bp    ← COMPILED (front 32), PURE: `Metadata`/`OpenGraph`/`TwitterCard`/`Icons`/`Viewport`, the merge rule, `renderHead`/`renderViewport` over std `escape`
│   │   │   ├── signal_runtime.mjs ← HOST (js): `capture` — a boundary's raise as a `@Result` value; the renderer's other catches are std's `failure.attempt` / `attemptTask`
│   │   │   └── sidecars/jhonstart_signal.erl ← HOST (BEAM): the same cell
│   │   └── test/
│   │       ├── render_test.bp ← `botopink test` flat suite: the walker, the hole, the fill, the globals, the payload (front 30) — both rows
│   │       ├── styled_sheet_test.bp ← `botopink test`: `compose` provides `StyledContext` — a `styled` component computed at render, rendered twenty times, written once to `renderedStyles()`; `resetRender()` empties it (front 119 step 1) — both rows
│   │       ├── streaming_test.bp ← `botopink test` flat suite: `render`/`renderStream` over a recording `Response`, composition, signals before and after the first chunk, the plugin order (front 30) — both rows; the fill order and the boundaries' concurrency are told by std `async` gates (the posts boundary answers once the recorder has WRITTEN the aside's fill; two loaders cross a pair of gates), never by `delay`s under an elapsed-time budget
│   │       ├── routes_test.bp ← `botopink test` flat suite: the four markers, `uiTable()` through `routing`, the params accessors (front 30) — both rows
│   │       ├── metadata_test.bp ← `botopink test` flat suite: the merge rule row by row, the head's order and escaping, the viewport (front 32) — both rows
│   │       ├── error_boundary_test.bp ← `botopink test` flat suite: the catch, the digest, signals passing through, the file conventions (front 31) — both rows
│   │       ├── client_app_test.bp ← `botopink test` flat suite: `clientApp` start, the two signals, the target check (front 26 Step 6) — both rows
│   │       ├── router_test.bp   ← `botopink test` flat suite: the route snapshot, its accessors and the pair decoder (front 26) — both rows
│   │       ├── server_test.bp   ← `botopink test` flat suite: the request record, the six cells, the `@Task` component and loader conventions (front 28) — both rows
│   │       └── client_test.bp   ← `botopink test` flat suite: the `#[client]` emit, a whitelisted props record, the island, the hole and the poison pill (front 29) — both rows
│   ├── jhonstart-emilia/ ← MEMBER (front 30, additive): the bridge — `plugin() -> RenderPlugin` over emilia's `flush()`, contributing the payload's `s`; the ONE member naming both jhonstart and emilia
│   │   ├── botopink.json  ← name jhonstart-emilia, files [root.bp], dependencies { jhonstart, jhonstart-html: { workspace: true }, emilia: { path: ../../../emilia/modules/emilia } } — `jhonstart-html` for the tests' DSL cell only
│   │   ├── src/root.bp    ← `plugin()`, `classesIn(css)`; the flushed names per render in a host cell
│   │   └── test/bridge_test.bp ← `botopink test`: the styled page's one head `<style>`, a streamed boundary's fill style before its markup, `s`, `close` (front 30); no file of the core's `src/` names emilia (read with std's `io.fs`); front 48's rendered cells — contract 4's `e_f51c2501` on a rendered document, the builders and the `html` DSL byte-identical over the class slot with `withAttrs` / `attrValue` reading it back, static-first `class="card e_…"` in array order — both rows
│   ├── jhonstart-forms/ ← MEMBER (front 67, additive): a form bound to a server action — `formAction`/`formAttrs`/`hiddenActionField`/`actionForm`, `submitForm`/`invokeAction`/`formMount`, the `actionState`/`formStatus`/`optimistic` hooks, `applyOptimistic`, the GET search form (`searchFormAttrs`, `searchHref`, `prefetchSearch`); the envelope, the state grammar, the RPC body and the action-id grammar (`formAction` checks `id.isActionId`, front 103) are the library `actions`'. Wire names come from `setWireNames(field, header)` (onze, at boot) — no literal here
│   │   ├── botopink.json  ← name jhonstart-forms, files [root.bp, form.bp], dependencies { jhonstart, jhonstart-link: { workspace: true } }
│   │   ├── src/{root.bp, form.bp, form_runtime.mjs, sidecars/jhonstart_forms.erl} ← the six browser cells, dual-target (the erlang twin answers the server's quiet truth and records the call for the test)
│   │   └── test/form_test.bp ← `botopink test`: the binding's markup, the body handed to the cell and the state read back, the hooks' server pass, the search form (front 67) — both rows
│   ├── jhonstart-html/ ← MEMBER (front 95): the `html """…"""` DSL — what `from "jhonstart-html"` gives a consumer; the core does not depend on it
│   │   ├── botopink.json  ← name jhonstart-html, src src/, entry root.bp, target commonJS, files [root.bp, html.bp], dependencies { jhonstart: { workspace: true } }
│   │   ├── src/
│   │   │   ├── AGENTS.md
│   │   │   ├── root.bp    ← `pub mod html;`
│   │   │   └── html.bp    ← COMPILED (front 118): the `html """…"""` template language — elements, components (a tag is a call with its attributes as labelled arguments, its content `children`), fragments, `{expr}` holes over core `Node`, rendering attributes, markup inside `if` / `case` / lambdas, slots, comments, raw-text bodies, `#[isRaw]`; one loop over the literal with an explicit frame stack, lowered twice (builder code + `CustomNode` overlay) → `@ExprCustom<Element>`; plus `isRaw`, `classList`, `classIf`, `hasContent`
│   │   └── test/
│   │       ├── html_test.bp     ← `botopink test` flat suite: markup lowers to the builders and renders — builders from "jhonstart"
│   │       ├── elements_test.bp ← `botopink test` flat suite: a tag from `elements.bp` resolves inside `html """…"""` (the DSL resolves in the CALLER's scope, so the only honest test is written from a consumer's position)
│   │       ├── template_test.bp ← front 118 steps 1–5 through `renderNode`: attributes, holes, void/self-closing tags, fragments, comments, raw-text bodies, markup in `if`/`case`/lambdas, components and slots, `raw`, `classList`, `#[isRaw]`
│   │       ├── template_expressions_example_test.bp · components_and_slots_example_test.bp · directives_example_test.bp ← the front's three spec examples, landed
│   │       ├── defects_test.bp  ← the four defects front 118 measured (static attribute, spaced value, nested self-closing tag, Element hole)
│   │       ├── view_test.bp     ← `-> View` and `-> @Component<Element>` accept one another (decision 276)
│   │       └── platform_test.bp ← what a template body may write, on both comptime runtimes (front 118 step 0)
│   ├── jhonstart-link/ ← MEMBER (front 27's code, relocated by front 95): client navigation's render-time half — what `from "jhonstart-link"` gives a consumer; the core does not depend on it
│   │   ├── botopink.json  ← name jhonstart-link, src src/, entry root.bp, target commonJS (inherits [commonJS, erlang]), files [root.bp, link.bp, reconcile.bp], dependencies { jhonstart: { workspace: true } }
│   │   ├── src/
│   │   │   ├── root.bp        ← `pub mod link; pub mod reconcile;`
│   │   │   ├── link.bp        ← COMPILED (front 27): `LinkProps` + `linkProps` + five `with*`, `Link`, `prefetchMode`, `layoutKey`, `LinkStatus`/`linkStatusOf`, and the browser half `linkMount` / `linkPrefetch` / `linkRouteKind` / the `linkStatus` hook over four DUAL-target cells (`link_runtime.mjs` / `sidecars/jhonstart_link.erl`); imports `Element` from "jhonstart"
│   │   │   └── reconcile.bp   ← COMPILED (front 27), PURE: `layoutKeys` + `sharedDepth` + `Navigation`/`navigationOf`/`replaceDepth` — the remount decision of a client transition — and the driver `applyTransition(current, target, dom: DomOps) -> @Task<@Result<Navigation, string>>` over the entry's six functions (`markup`, `replaceSubtree`, `startIslands`, `mountCount`, `scrollTo`, `markPending` — `data-jh-pending`, decision 363); imports `RouterState` from "jhonstart"; no host cell
│   │   └── test/
│   │       ├── link_test.bp     ← `botopink test` flat suite: the props, the anchor's seven attribute rows, the prefetch table, the layout key, and `use linkStatus()` read by a `#[client]` component (front 27) — both rows
│   │       └── reconcile_test.bp ← `botopink test` flat suite: `layoutKeys`/`sharedDepth`, and `applyTransition` over a RECORDING `DomOps` (inline `put`/`get` · `globalThis` cells; a three-island page counting mounts): the replaced depth, the call order, `data-jh-pending` set first and cleared last, a failed markup (front 27) — both rows
│   ├── jhonstart-dom-test/ ← MEMBER (front 30's browser half; targets [commonJS]): `src/fake_dom.mjs` — a minimal document (parser for the render's markup, `querySelector(All)` over `tag` / `[attr]` / `[attr="v"]`, `template` content, `replaceChildren`, a serializer; `history` / `location` / `dispatchEvent` recorded) reached through `src/root.bp`'s `#[@External.Node]` cells and its `callFill(name, id)` / `callSignal(name)` wrappers — and `test/dom_test.bp`: the fill function (replaces its hole, idempotent, a missing hole dropped), `readPayload` (the last payload script, a refused text an `Error`), the signal function (relative redirect = `replaceState` + `popstate`, a listed absolute one `location.replace`, an unlisted one nothing, not-found swaps `[data-jh-root]` and drops later fills). No DOM on the BEAM, hence commonJS only (`decisions-pending.md` 30-g) — a structural restriction under `00-gate` gate-d: `botopink build --target erlang` refuses the member with `` `callGlobal` has no `#[@External.<Target>(…)]` for the erlang backend `` at `src/root.bp:37`
│   └── jhonstart-test/ ← MEMBER (front 95; the helpers of `specs/1.0.10-beta/04-jhonstart/modules.md` § 5): `assert<Subject>(loc, …)` over `snap`'s `assertAs`, each with a pure `<subject>Text` twin, plus fixtures and the render harness
│       ├── botopink.json  ← name jhonstart-test, files [root.bp, harness.bp, assert_*.bp], dependencies { jhonstart, jhonstart-link, jhonstart-forms: { workspace: true } }
│       ├── src/root.bp    ← `pub mod` per helper file + one inline `test` proving the core resolves
│       ├── src/harness.bp ← `fixtureRouter`, `fixtureRequest(method, path, lists = "")`, `fixturePageOver`, `stubEnvelope` (actions' `writeEnvelope`), `renderToStream` (declaration order), `Navigation` + `simulateNavigation(current, target)`, `recordingResponse` / `RecordedResponse` / `renderRecorded` / `renderStreamCollect` (inline recording cells: `put`/`get`, a `globalThis` entry)
│       ├── src/assert_{html,route,link,server,island,stream,render,error_boundary,metadata,form}.bp ← `assertHtml`/`assertHtmlLines`, `assertRoute`/`assertActiveLink`, `assertLink`/`assertNavigation`, `assertRequest`, `assertClientBundleEntry`, `assertStream`, `assertDocument`/`assertResponse`/`assertPayload` (+ `jsonMembers`), `assertErrorBoundary`, `assertMetadata`/`assertViewport`, `assertForm`/`assertActionState`/`assertOptimistic` — texts per `test-snap.md` § 0.2
│       └── test/helpers_test.bp + test/__snapshots__/ ← every twin against `test-snap.md`'s literal, and one accepted snapshot per helper family — both rows
├── examples/
│   ├── jhonstart-counter/  ← MEMBER: `use state` + the client runtime under node; both rows
│   ├── jhonstart-markup/   ← MEMBER: the `html """…"""` DSL cross-module (inherits [commonJS, erlang]) — was `examples/jhonstart-html/`, renamed by front 95 because a member name is unique in the workspace and the DSL member took it
│   ├── jhonstart-todo/     ← MEMBER: builders + hooks + SSR; both rows
│   ├── blog-ssr/           ← MEMBER (`modules.md` § 8, targets [commonJS, erlang]): `src/repo.bp` fixtures; `src/app/` — `layout` (RootLayout, metadata, viewport), `loading`, `error`, `not_found`, `global_error`, `blog/slug/{page,metadata}` (PostPage with two sequential loaders, postPanel, generateMetadata) — a module name is an identifier, so Next's `not-found` / `[slug]` are `not_found` / `slug`; `test/blog_test.bp` 10 snapshots
│   ├── nav-shell/          ← MEMBER (targets [commonJS, erlang]): `Sidebar`, `DocsIndex` (prefetch off per row), `CheckoutLink` (LinkStatus); `test/nav_test.bp` 6 snapshots
│   ├── islands/            ← MEMBER (targets [commonJS, erlang]): `#[client]` LikeButton / ThemeProvider with their `#[clientProps]`, `PostList` / `PostListFrom(posts, first)` numbering islands, `RootLayout(theme, page)` in a server slot; `test/islands_test.bp` 5 snapshots
│   ├── forms/              ← MEMBER (targets [commonJS, erlang]): `createPostForm` / `CreatePostForm`, `likeWidget` / `LikeWidget` (optimistic + form status), `searchForm`; `test/forms_test.bp` 7 snapshots
│   └── document-shell/     ← MEMBER (targets [commonJS, erlang]): `documentShell` + `doctype` with constructors, `documentBody` in the `html` DSL, `main.bp` building `<main>` with `el`; `test/shell_test.bp` 4 snapshots
├── refusals/               ← NOT members: one project per compile-time refusal of the library, each with the `expect.txt` its `botopink check` must print (stage 6 of the gate, `scripts/check-refusals.sh`)
│   ├── layout_plain_element/   ← `#[layout]` on `-> Element` (decision 117; the guide's `OldLayout`)
│   ├── page_plain_element/     ← `#[page]` on `-> Element`
│   ├── template_task_element/  ← `#[template]` on `-> @Task<Element>`
│   └── html_*/                 ← front 118: the `html """…"""` refusals — a `?T`, a record, a function in a hole; markup as an operand; `[name]={…}`; `class:list`; `set:html`; `slot="…"`; an unbound component and an unbound annotation; content to a component without `children`; a narrower `children`; two `#[isRaw]`; a mismatched closing tag; a kebab-case attribute but `data-*`, an event attribute, a spread on an element and a non-`string` `data-*` value (decision 351); `<style>` in markup (decision 338)
```

`modules/jhonstart-test/` is the `<lib>-test` member
(`specs/1.0.10-beta/02-packaging/README.md` § 5): it stands on the
`snap` library (`import {assertAs} from "snap"`, a git dependency of the member and of every
example that records a snapshot; decision 391) — a helper computes its text (the `<subject>Text`
twin) and hands it to `assertAs(loc, "<subject>", text)` with the CALLER's `@src()` — and
re-exports nothing from std or `snap`. A snapshot is accepted by renaming its `.snap.new`
after comparing it with `test-snap.md`'s literal; never by a flag.

`modules/jhonstart-link/` holds front 27's `link.bp` and `reconcile.bp` and
their two suites, moved out of the core by front 95 as a relocation only: the
one edit is `import {Element, ElementBase} from "jhonstart";` in `link.bp` (and
the same line in `link_test.bp`); nothing in the core imported either module.
The member declares no `targets`, so it inherits both rows — its code is pure;
the four `#[@External.Node]` cells front 68 brings reopen that question
(`specs/1.0.10-beta/04-jhonstart/modules.md` § 4).

The other members `specs/1.0.10-beta/04-jhonstart/modules.md` § 1 plans —
`jhonstart-forms` (67) and the `jhonstart-emilia` bridge (30, decision 113) —
are created by those fronts, not here.

The five example projects of `specs/1.0.10-beta/04-jhonstart/modules.md` § 8
(`blog-ssr`, `nav-shell`, `islands`, `forms`, `document-shell`) each test
through `jhonstart-test`'s helpers into their own `test/__snapshots__/`, every
snapshot compared with `test-snap-examples.md`'s literal before it was accepted.
A tree holding untrusted text is snapshotted through front 30's `renderNode`
(the one escaping point), not the frozen `renderToString`.

`refusals/` is outside both globs too: each subdirectory is a project that
must NOT compile — a decorator's `decl.fail`, which no `test { }` block can
hold — depending on the core by `{ "path": "../../modules/jhonstart" }`. Its
`expect.txt` lists the lines `botopink check` must print, verbatim: the message
and its ` --> src/main.bp:<line>:<col>` location. A new refusal of the library
adds a directory here in the commit that adds the `decl.fail`.

A compiler defect this library hits is handed to its owning front as a
`tests/language` cell filed to `01-compiler/12-language-tests`, or as a cell in
the member that hits it — never as a tree the gate does not run (1.0.10's four
jhonstart-free reproductions are closed in the compiler and deleted).

## Module tree (`root.bp`)

`modules/jhonstart/src/root.bp` is the explicit module-tree root — the package builds from it, not
a deprecated blind `src/` scan. It declares the four compiled public modules
`pub mod element; pub mod hooks; pub mod html; pub mod elements;` (all public
surface; `hooks` and `elements` import `Element` from `element`, so the resolver
compiles `element` first). Each track-C front **appends** its own `pub mod` line
in front-number order and never reorders or edits another front's line;
`botopink.json`'s `files` list takes the same entries in the same order.

Front 27's own README § Step 5 says its two lines are HANDED to front 94 rather
than written by the front, and front 29's § Step 5 and § *Does not touch* say the
same. That is not what the landed tree does: front 26 (`d9f1f3c`), front 94
(`dc979b6`) and front 28 (`6d6c007`) each appended their own line to `root.bp`
and `botopink.json` in their own commit, and fronts 27 and 29 do the same.
Recorded as a spec/tree disagreement, not resolved here — front 94 is closed and
there is nobody left to hand a line to.

**A sibling-module import always names its module** — `import { Element } from
"element";`, never the bare `import { Element };`. Both type-check, but
commonJS lowers the bare form to `require("../module")`: a path that resolves
while jhonstart is compiled on its own and not when it is a dependency, which
is how `examples/jhonstart-counter` and `-todo` came to build and then die with
`Cannot find module '../module'`. Reported to botopink-lang as a codegen defect
(`src/codegen/commonJS.zig`, the require path of a dependency's sibling
module); naming the module is the workaround and reads better anyway.

There is no declaration module left in this package. `.d.bp` modules are not
resolved by `mod` paths (the resolver follows only `<name>.bp` /
`<name>/mod.bp`), so a `.d.bp` had to be wired through `files` alone and was
never in the build tree — which is exactly why `router.d.bp` and `server.d.bp`
were promoted rather than filled in. A host-bound module here is now an ordinary
`.bp` that ships its two host halves beside it.

## Layers

| Layer | Analog | ContextBase | Surface |
|---|---|---|---|
| core | React | `Element` | `element.bp` + `elements.bp` + `hooks.bp` (**compiled**); the `html.bp` DSL in the `jhonstart-html` member (**compiled**) |
| app | Next.js | `Element` | `router` (**compiled** — front 26), `server` (**compiled** — front 28), `link` + `reconcile` (**compiled, pure** — front 27), `client` (**compiled, pure** — front 29) |

## Conventions

- **Prefer real `.bp`**: implement in botopink whatever the language can express.
  `element.bp` (type, builders, `renderToString`) and `hooks.bp` (the
  `{value, set}` hook family) are ordinary `.bp`. Keep `.d.bp` only for genuinely
  host-bound intrinsics or async-gated surface — and say which gap gates each one.
- Builders take a `Children` arg (`div([a, b])` / single / `string` — the G4
  coercion); the **list form** is what V1 renders and what `html` emits. The
  trailing-lambda sugar (`div { [a, b] }`) is a recorded follow-up.
- A hook is `pub fn <noun>(…) -> @Component<R>` — the noun, never a
  `use` prefix (`counter`, `router`, `toggle`; not `useCounter`). Activation is
  `val x = use <noun>(…)` in the static prefix of a body whose return is
  `@Component<_>` (the return is the effect) — a
  component (`-> @Component<Element>`) or a custom hook (`-> @Component<_>`);
  the binding never reuses the hook's name (`val r = use router()`).
- Hook bodies are pure/synchronous (the server pass / first render): `state`
  yields its initial value, `memo` computes eagerly, `effect` is a no-op. Hook
  bodies are unit-tested by **direct call** (no `use`) in `test {}`, awaited —
  on commonJS every `@Component` body is an `async function` (botopink decisions
  104/128) — and a component called and awaited renders the server pass. Client reactivity is
  `modules/jhonstart/src/client_runtime.mjs`
  (the same nouns over jhonstart's own loop), which the client build resolves
  `jhonstart/hooks` to — the bundler's substitution (front 68); under node,
  `examples/jhonstart-counter/client.mjs` seeds `require.cache` the same way.
  The five nouns are not re-declared in `client_runtime.bp`: a package's import
  surface is flat and a second `state` shadows `hooks.state` for every consumer
  (last module wins, silently, even from a non-`pub` `mod` — measured).
- `renderToString` is **synchronous** (`.bp`); SSR needs no async.
- A decorator's parameters are `comptime x: @Expr<T>` (decision 364) and the body reads
  `x.value` — `#[page("blog/[slug]")]`'s `seg.value` in `routes.bp`.
- Components are PascalCase (`Counter`, `Page`); fns/builders camelCase.
- Not embedded: do **not** wire jhonstart into `comptime/stdlib/prelude.zig` or
  `build.zig`.

## Compiler prerequisites (all generic, none jhonstart-specific)

jhonstart is a *consumer*. What it relies on:

- **Landed**: `context-inference` (`@Context`/`use`), `expr-templates` (`@Expr`),
  the G1–G4 gaps (fn-typed fields, labeled tuple types, `fn() -> T[]`, `Children`
  coercion), the generic `from "<lib>"` loader, and — new in this port — generic
  **cross-module nominal-type resolution** (a local component `fn … -> Element`
  whose result feeds an imported `renderToString`/`use` now type-checks; see
  `modules/compiler-core/src/comptime` `type_decl_registry` + `resolveTypeName`).
- **Landed** (markup front-end): `expr-custom` (`@ExprCustom<T>` + `CustomNode` +
  `q.custom`) now backs `html` — its body lexes/parses the markup into a token
  stream and lowers it twice (builder code + a `CustomNode` reference overlay the
  LSP reads), the sibling of erika's `erika "…"` SQL front-end. The comptime
  template body still sees only a native-JS prelude (no Option/`unwrapOr`), so the
  walk uses a stack + `indexOf` span recovery rather than a recursive descent —
  see `html.bp`'s header.
- **Still gated** (router / server, all generic core work):
  - (closed) the server data layer. `fn … -> @Task<T>` (then spelled with the
    pre-front-24 annotation) with a statement-level `await` compiles and RUNS on
    both rows, `test` blocks included — measured for front 28 against compiler
    `2e6bb4ac`. What remains
    of `use-await-prefix` / `async-generators` is not on this path;
  - (closed) `use request()` — `request()` is a hook since botopink front 21;
  - (closed) the `Element` model **does** carry an `attrs: Array<#(string,
    string)>` slot, so `href`/`value`/`class` render in pure `.bp`. `Link` is
    written and compiled since front 27; what it still lacks is the host
    navigation runtime, which is front 68's bundle and front 60's route-kind
    table, not an attribute slot and not a language gap;
  - (closed) an imported declared default is applied at the call site (C-04
    across a module boundary), and a record has the update form
    `LinkProps(..p, prefetch: false)`. Front 27's `Link` keeps its `LinkProps`
    record and the `with*` helpers, now written with the update form.

  (The "bare imported template-fn binding" gap that originally lived here
  closed in v0.beta.8 via the generic-loader-binding keystone, with the
  package-default-dsl handle binding following in v0.beta.14 — consumers
  can `import {html} from "jhonstart-html"` beside `import {div, …} from
  "jhonstart"` today.)

## What jhonstart fronts 27–32 consume from front 26

Front 26 (the router) is the first landed front of this track after the element
surface, and fronts **27** (link), **28** (server components), **29** (client
directive), **30** (streaming), **31** (error boundaries) and **32** (metadata)
all read the answer it produces. This is the surface they may rely on; none of
it changes without a note here. Everything below is reached by a consumer as
`import { … } from "jhonstart"` and is green on **both** rows — measured with a
`path` dependency on `modules/jhonstart/` from a package outside this tree,
rendering a `@Component<Element>` component through `use pathname()` /
`use selectedLayoutSegment()` / `use params()` and asserting the markup.

| What | Where | Shape |
|---|---|---|
| The snapshot | `RouterState(path, params, search, pattern, selected)` | a plain record, no behavior. `params`/`search` are `Array<#(string, string)>`, `selected` the layout depth (root layout `0`) |
| Its accessors | `r.param(n)` · `r.searchParam(n)` · `r.segments()` · `r.segment()` | every one answers a plain `string`/`Array<string>`, `""` when absent or out of range. Never `?string` |
| The pair decoder | `pairValue(pairs, name)` | the package's ONE pair-list decoder, FIRST match of a duplicated key. Fronts 28 and 32 import it from here rather than growing a copy |
| The pair codec | std's `encoding.formParse` · `encoding.formStringify` | decision 116 rule 4: percent-aware, the codec rakun uses; the package carries no copy. `formStringify` writes NO leading `?` — the caller adds it |
| The segment readers | `patternSegments(pattern)` · `segmentAt(segments, i)` | typed-parameter readers |
| The build | `snapshot()` | five cells in, the record out. No `?T` unwrap that can fail |
| **The writer** | `fill(path, params, search, pattern, selected)` | the ONE way route state is installed, and the seam fronts 27/28/29 need. `params`/`search` go in querystring-encoded, exactly as the payload's `m` and `q` carry them. Every field at once — a half-updated snapshot is a component reading the previous route's params against the next route's pattern |
| The six hooks | `router` · `pathname` · `params` · `searchParams` · `selectedLayoutSegment` · `selectedLayoutSegments` | each `-> @Component<T>`, each one read of `snapshot()`. `selectedLayoutSegments()` is root-first |
| The six verbs | `push` · `replace` · `back` · `forward` · `refresh` · `prefetch` | free functions over one cell, `-> i32` nobody reads. Free and not methods: records are immutable and there is no assignment to a `self` field anywhere in this tree |
| What a verb recorded | `lastNavigation()` | `"<kind> <href>"`, `""` when nothing has. On erlang this is the 307 front 28's dispatcher writes; in the browser the last href the History API was handed |
| The host halves | `src/router_runtime.mjs` · `src/sidecars/jhonstart_router.erl` | cell for cell, so one set of assertions runs on both rows. The BEAM store is the CALLING PROCESS's dictionary: a request is a process, the snapshot dies with it, two concurrent renders cannot see each other's route |

A function-valued record field is called in place (`v.tagOf(e)` applies the
field on every row).

**One rule that shows on both** — a hook called WITHOUT `use` keeps its
`@Component<T>` type. The type is transparent to a property or a method
(`ps.length`, `segs.join("/")`, `r.param("slug")`) and **not** to a typed
parameter: `pairValue(params(), "slug")` is `type mismatch: expected array, got
Context`, and binding through a `val` does not change it. Only `use` strips the
capability. So an array-valued hook is usable as a value only under `use`, and
the two `string` hooks compare directly either way.

**Three things front 26 does NOT provide, so nobody looks for them here.**

1. **A matcher and a route table parser.** `matchPath`, `parseTable` and
   `writeTable` are rakun front 22's, written once and compiled twice. A router
   with its own matcher is a router that disagrees with the server about
   precedence on the routes nobody tested. `matchPath`'s result already carries
   the **root-first layout chain** — do not rebuild it — and a route parameter
   is read with **`paramOf(m, name)`**, never `m.params.at(name).unwrapOr("")`:
   through the optional binder the match's type is lost.
2. **The `ElementView<Element>` adapter.** rakun front 23's handoff says "front
   26 writes it". It cannot be written here, and the reason is structural, not
   a preference: `ElementView<El>` is rakun's type, so the adapter needs
   `import { ElementView } from "rakun"`; jhonstart declares no dependency on
   rakun; and rakun's member is `targets: ["commonJS"]`, so adding one would
   red jhonstart's erlang row — the row front 26 is assigned to. The adapter
   belongs to **front 28**, the front where jhonstart meets rakun's SSR
   pipeline, together with the `dependencies` entry that makes it possible and
   the targets decision that entry forces. Front 28 should also expect rakun's
   own rule above to bite it: every field of the adapter is a **lambda**
   (`{ t -> isVoidTag(t) }`), never a bare function name.
3. **A `Link`.** It did not come along from `router.d.bp`. It is front 27's
   `link.bp` (landed; the `jhonstart-link` member since front 95), and front 26 adds nothing to it and reads nothing
   from it.

### The `query` hole, closed

rakun front 23's README claims the dynamic marking "is done by the accessor,
not by a developer remembering to declare it", and front 23 measured that this
could not be true as written: `searchParams(route)` marked, but `route.query`
was a public field of `PageContext` and a direct field read cannot be
intercepted. A render that reads the query and is cached as static serves one
reader's `?sort=desc` to every other reader, silently.

`PageContext` is jhonstart's since decisions 113/114, so jhonstart closes its
half by the strongest of the three fixes front 26 listed — **the field is
gone**:

- `PageContext(pathname, pattern, params, rest)` carries **no `query`**. The
  render fills the query into the route snapshot; `render.bp`'s `enterDepth`
  re-reads it from there per layout, and `streaming.bp` hands the raw
  `PageInput.query` to each boundary's process.
- The two readers of per-request input a component has — `searchParams()`
  (router) and `request()` (server, and through it `cookies()` / `headers()`)
  — call `markDynamic()`, a flag in the router's host store
  (`router_runtime.mjs` / `sidecars/jhonstart_router.erl`).
- `renderWith` clears the flag when it starts; the payload's `d` is
  `renderIsDynamic()`, no longer a constant `true`. On erlang a boundary
  renders in its own process, so `Resolved.dynamic` carries that process's
  flag back and `carryDynamic` ORs it into the render's before the payload is
  written.

`streaming_test.bp` "dynamic: …" asserts a static page (`"d":false`), the
query and the request each marking, a boundary's read marking the page from its
own process, and the flag not leaking into the next render. rakun's half — its
own front-22 `PageContext` and `searchParams(route)` — leaves with rakun's page
registry (decision 114); `status.md` records it.

## Front 28 — the request, and the three things it dropped

### The `Http` base, and why it is gone

`server.d.bp` carried a `behavior Request` with three bodyless methods and a
phantom `@Context` base called `Http` — "no members … supplied by the host, the
server-side mirror of `Element`". Front 28 dropped both: a server component is
`fn Page() -> @Component<Element>` (botopink decision 354 — `Element implement
@Renderable`, no base in the wrapper), a client hook is type-legal inside a server
component, and the client boundary is front 29's `#[client]` rule rather than a
type. What a body reads from above it is a context (`use context(…)`), and the
render's own root context is `ElementContext` (354 (7), front 26).

The `Request` behavior goes with it. A behavior with bodyless methods had no
verified implementor anywhere in this tree; `RequestData` is a plain record, the
same call front 26 made for `RouterState`, and a record is what a `use`
capability has to yield anyway.

`server.d.bp` was never in the build tree (`.d.bp` is not resolved by `mod`), so
no built consumer existed to break.

### Why the request cells are jhonstart's own

Front 28's README binds the six cells to front 62's
`#[@External.Erlang("rakun_request_context", …)]` and says there is to be no
Node cell in the file. Neither half is writable, and both halves were measured
against compiler `2e6bb4ac` on 2026-09-21:

1. **An erlang-only cell reds the commonJS COMPILE at its call site.** Not at
   run time — the README's test plan expects "a js run of `request()` is
   expected to fail at the first cell", and it is worse than that:

   ```text
   error: `__jhReqMethod` has no `#[@External.<Target>(…)]` for the node backend
    --> src/main.bp:5:12
   ```

   `modules/jhonstart` is compiled on **both** rows, so an erlang-only cell
   takes the whole member — every landed assertion in it — off the commonJS
   row the moment `request()` calls it. Front 26 measured the same thing for
   the router's five reads and carries the same note.

2. **`rakun_request_context` has no BEAM row to bind to.** rakun's member is
   `targets: ["commonJS"]`. On erlang — front 28's *assigned* target — every
   cell answers `{error,undef}` at run time, so no assertion that reads the
   request could RUN, and `botopink build --target erlang` would still exit 0
   because a build transpiles and never invokes `erlc`.

So the seam is **here** and it is `pub`, which is the conclusion front 26 already
reached and wrote down for the route snapshot: a server that reached into
another library's process dictionary keys would be coupled to them forever.
`jhonstart_server` / `server_runtime.mjs` are the two halves, cell for cell;
`enterRequest(req)` is the one writer and `leaveRequest()` its pair; front 30's
render calls both, once per render, with the `RequestData` onze handed it.

`enterRequest` is deliberately **not** front 26's `fill` under another name, and
the two stores stay separate: a route snapshot is re-filled DURING a render (its
`selected` is the layout depth) while a request is entered once and is constant
for the whole render. Folding them would make "the request" mutate mid-page.

### Two things front 28 does NOT provide

1. **`escape.html` / `escape.attribute`.** They are front 01's and
   `libs/std/src/escape.bp` does **not exist** in compiler `2e6bb4ac` — the
   nineteen std modules have no escaping among them. `renderToString` escapes
   nothing (`element.bp:56`, frozen), so a server component renders
   attacker-influenced text verbatim today. `server.bp` hand-rolls no
   replacement: a stand-in would be a second answer to "what is an escaped `&`"
   the day the real one lands. `test/server_test.bp` PINS the unescaped answer,
   so the change shows as a red cell rather than a silent difference.
2. **Parallel awaiting.** No `awaitAll`, no `race`, no `allSettled`. `@Task`
   is eager on the erlang row (botopink decision 120), so two loaders
   awaited in sequence cost the **sum** of their round trips even when their
   results are independent. The fix is front 02's spawn-and-gather over
   **unstarted tasks** (`[{ -> loadPost(s) }, { -> loadSidebar() }]`), not a
   `map` over Tasks, which would simply run them in order. jhonstart names
   front 02 and ships no second answer.

### The `ElementView<Element>` adapter is still unassignable here

§ *What jhonstart fronts 27–32 consume from front 26* hands the adapter to front
28 "together with the `dependencies` entry that makes it possible and the
targets decision that entry forces". Front 28's own README does **not** ask for
it — it cites rakun 23 and 62 read-only and nothing more — and the structural
obstacle front 26 recorded has not moved: `ElementView<El>` is rakun's type, so
the adapter needs `import { ElementView } from "rakun"`, jhonstart declares no
dependency on rakun, and rakun's member is `targets: ["commonJS"]`, so the entry
would red jhonstart's erlang row — the row front 28 is assigned to. It is not
written here. The two specs disagree about who owns it and that is a spec
question, not a code one.

### What fronts 29–32 consume from front 28

| What | Where | Shape |
|---|---|---|
| The request | `RequestData(method, path, params, query, headers, cookies)` | a plain record, no behavior. Every plural field `Array<#(string, string)>`; **no `body` field** — form bodies are front 24's, route-handler bodies front 25's |
| Its accessors | `r.param(n)` · `r.queryParam(n)` · `r.header(n)` · `r.cookie(n)` | plain `string`, `""` when absent, never raises. All four through front 26's `pairValue`, so a duplicated key means one thing |
| The build | `request()` | six cells in, the record out. A plain function, not a hook, until front 19 step 2 |
| **The writer pair** | `enterRequest(req)` · `leaveRequest()` | the ONE way request state is installed and removed, called by front 30's render once per render. The four pair lists are stored `encoding.formStringify`-encoded. Between the two `request()`/`cookies()`/`headers()` read it; outside them they RAISE |
| The shortcuts | `cookies()` · `headers()` | the only two re-exported. `after`, `connection`, `draftMode` and memoization are front 62's, called from there |
| The render entry | `renderServerComponent(component) -> @Task<string>` | takes an **unstarted thunk** `fn() -> @Task<Element>`, awaits exactly once, renders synchronously afterwards; `renderComponent` takes a `fn() -> @Component<Element>` thunk |
| The host halves | `src/server_runtime.mjs` · `src/sidecars/jhonstart_server.erl` | cell for cell, so one set of assertions runs on both rows. The BEAM store is the CALLING PROCESS's dictionary: a request is a process, it dies with it, two concurrent renders cannot see each other's cookies |

**Two call-site rules.** The first only shows on the erlang row and is a compiler
defect, not a convention: **a bare function name used as a value lowers to an
unbound erlang variable**, so `renderServerComponent({ -> Page(ps) })` is green
on both rows while `renderServerComponent(Page)` compiles on commonJS and fails
`variable 'Page' is unbound` on erlang. It is the same shape rakun's front 23
records for the fields of its `ElementView` and it is **reported, not worked
around**. The second shows on both: a function has one return and so one effect
(botopink decision 118), so a server component that loads data is
`fn … -> @Task<Element>`, and one that also activates a hook is
`fn … -> @Component<Element>` (decision 128: `@Component` extends
`@Task`). Neither is a `@Result`, so neither can propagate a failed load with
`try` — a component handles the error in its body (`try await load() catch …`,
`case`, an error screen; decision 121).

## Front 27 — client navigation, and the half that is not written

`link.bp` and `reconcile.bp` are the RENDER-TIME half of a `<Link>`: the anchor,
its props, the prefetch decision and the remount decision. Every one of them is
**pure** — `reconcile.bp` declares no host cell of any target and `link.bp`'s
four cells are dual-target — so all 46 assertions run on both rows and `Link` renders during the server pass exactly as
it renders in the browser.

| What | Where | Shape |
|---|---|---|
| The props | `LinkProps(href, prefetch, replace, scroll, target, className)` | a plain record. `linkProps(href)` fills Next's defaults; `withPrefetch`/`withReplace`/`withScroll`/`withTarget`/`withClass` each return a NEW record with one field changed |
| The anchor | `Link(props, children) -> Element` | `<a href=… data-jh-l="1">`, plus one attribute per prop that DIFFERS from its default. `target` and `class` are real attributes, the other three are `data-jh-*` |
| The prefetch decision | `prefetchMode(kind, hasLoading, requested) -> string` | `"full"` / `"partial"` / `"skip"`, Next's § 8 table verbatim. BOTH inputs are front 60's; jhonstart computes neither |
| The layout key | `layoutKey(segments, depth)` | `"/" + segments.take(depth).join("/")`. `segments` is front 26's `RouterState.segments()`, so the client's key and the server's are the same string |
| The remount decision | `layoutKeys(segments)` · `sharedDepth(current, target)` | root-first keys including the root; the common-prefix length. `[0, keep)` stays mounted, `[keep, n]` is replaced. Never `0` — the root layout is never remounted |
| The in-flight status | `LinkStatus(pending, href)` · `linkStatusOf(href)` | the pure derivation from the href the browser half reports, `""` being idle. Read with `use linkStatus()` only inside a `#[client]` component (decision 363); a server-rendered `Link` reads no hook — its pending state is `data-jh-pending`, styled with `[data-jh-pending]` |
| The driver | `applyTransition(current, target, dom: DomOps)` · `navigationOf` · `replaceDepth` | a navigation to the current path touches nothing; otherwise `markPending(href, true)`, `await markup(href)`, `replaceSubtree(d, html)` and `startIslands(d)` at `d = shared - 1` (the deepest shared segment's root: its CHILDREN are replaced, so the root layout never is), `scrollTo(d)`, `markPending(href, false)`. A failed `markup` replaces nothing, clears the mark and is the answer. Islands above `d` are never started again — `mountCount(name)` is the observable. Adopted by onze's entry in `07-onze/50` step 6 |

**No arbitrary-attribute parameter.** `Link` has no pass-through `attrs` list —
only `target` and `className`, through `LinkProps`. An anchor that accepts any
attribute is an anchor that can be handed its own `data-jh-l`, and that marker
is what the browser half queries on.

### What fronts 60 · 67 · 68 have to bring, and why none of it is stubbed here

| Missing | Owner | Note |
|---|---|---|
| `__jhLinkMount()` | 68 | delegated click interception + an intersection observer over `[data-jh-l]`. The generated entry calls it ONCE, after hydrating the islands, alongside front 67's `__jhFormMount()`. Front 29 owns the per-island hydrate point, not the entry, and does not call this |
| `__jhLinkPrefetch(href, mode)` | 68 | warms the client route cache; `mode` is `prefetchMode`'s answer |
| `__jhLinkStatus()` and `linkStatus() -> @Component<LinkStatus>` | 68 · 26 step 8 | the hook is `return linkStatusOf(__jhLinkStatus());`; `#[clientOnly]` and the deletion of its erlang twin wait on 26 step 8's markers (`01-checker` step 23's `Decl.hooks`), and so does the refusal of a `use linkStatus()` outside a `#[client]` component (decision 363) |
| `__jhLinkRouteKind(href)` | 60 | reads the route-kind table front 60 emits into the bundle |
| the entry's `DomOps` | `07-onze/50` step 6 | the six functions `applyTransition` calls: `replaceChildren` on the segment root the render marks, the route's starters, the route cache (front 22's kind flag says whether the markup had to be fetched), `data-jh-pending` on the links to the target; front 29's `data-jh-s` adoption and front 31's `data-jh-e` re-anchoring are the entry's `replaceSubtree` |

Two measurements make declaring them today wrong rather than merely early, and
they point in opposite directions:

1. **A called node-only cell reds the ERLANG build at its call site.** Measured
   2026-09-21 against compiler `2e6bb4ac`, smallest program:

   ```bp
   #[@External.Node("./rt.mjs", "status")]
   declare fn __cellStatus() -> string;
   pub fn statusOf() -> string { return __cellStatus(); }
   ```

   ```text
   $ botopink build --target commonJS     # Compiled in 95.64ms
   $ botopink build --target erlang
   error: `__cellStatus` has no `#[@External.<Target>(…)]` for the erlang backend
    --> src/main.bp:5:12
   ```

   It is the exact mirror of the erlang-only → commonJS measurement `router.bp`
   and `server.bp` both carry, and it applies because these modules land in the
   core member, compiled on both rows. A `linkStatus()` wrapper would take all
   103 landed assertions off the erlang row.

2. **A declared and never-called node-only cell is fine** — that is why
   `client_runtime.bp`'s `clientRender` does not red erlang, and it was
   re-measured here. So the four declarations are cheap. What is not cheap is
   the module they name: `jhonstart/client-runtime` is front 68's generated
   bundle and does not exist, so the declaration would emit a `require` of a
   file nobody writes, silently at build time and loudly at run time. A host
   cell that answers what nobody can check is exactly what `router.d.bp`'s
   one-line `Link` was, and the reason it never became real.

## Front 29 — the client boundary, and what it does NOT check

`client.bp` is the boundary's VOCABULARY. It is pure — no host cell of any
target — so all 22 assertions run on both rows and an island renders during the
server pass exactly as it renders in the browser.

| What | Where | Shape |
|---|---|---|
| The marker | `#[client]` | a `@Decl`-first comptime fn. Records the meta `component` (`@typeInfo(<Name>).meta.client.component`, decision 216) — a compile-time constant, never a call into a host registry, because a Node-only call would break the erlang server render |
| The props rule | `#[clientProps]` | on the props RECORD, because `@Decl` does not expose a function's parameters. Whitelist: `string` · `i32` · `f64` · `bool` |
| The island marker | `islandId(n)` · `islandAttrOf(id)` · `islandAttr(n)` | decision 77: `islandAttrOf` is the ONE occurrence of `"data-jh-i"` in this tree. Front 23 fills `RenderHooks.islandAttr` from `islandAttr`; front 68's entry imports the same function |
| The island | `Island(id, component, props)` · `clientMount(island, children)` | the placeholder carries the id and NOTHING else; the component name and encoded props go to the payload's `i` row |
| The payload row | `islandEntry(island)` | `#(id, component, "k=v&k=v")`, encoded with std's `encoding.formStringify` (decision 116 rule 4) |
| The decode | `propsOf(raw)` | the pure half of the front's `propsFor(name)`; `propsOf("")` is `[]` |
| The hole | `serverSlotAttr()` · `serverSlot(children)` | `data-jh-s="1"` — the server-rendered subtree the client ADOPTS and must not reconstruct |
| The poison pill | `serverOnly()` | the value is meaningless; its presence in a module's import list is the signal |

**What is enforced today** — four comptime refusals, no flag that turns them off
(decision 67), each located at the annotation: `#[client]` on a non-`fn`;
`#[client]` on a fn whose reflected `returnType` is not `Element` or
`@Component<Element>` (a `-> @Task<Element>` server component
reflects as `"@Task<Element>"`); `#[clientProps]` on an
enum; a field outside the four-scalar whitelist.

**What is NOT enforced by anything in this tree**, and it is the front's whole
reason to exist, so it is written here rather than implied:

- that a `#[client]` component's parameter record carries `#[clientProps]` at
  all — `@Decl` has no parameters;
- that no module reachable from a `#[client]` component imports `serverOnly`, or
  `request`/`cookies`/`headers`;
- that the props written into an island's `i` row are the ones the record
  declares.

All three are module-GRAPH predicates. **Front 29 defines the boundary; front 68
enforces it.** Today a secret read on the server still reaches the browser if it
is written into an island's props, and nothing here notices.

### The whitelist is four names, not the spec's six

The spec's `string[]` and `i32[]` were left out while `Field.typeName` erased an
array's element type (`Array<string>` and `Array<Element>` both reflected as
`"Array"`, `string[]` as `""`). `@Decl` now spells every type as the source
writes it (`Array<string>`, `string[]`, `fn(i32) -> i32`), so the widening is
this front's to make; until it lands an array-valued prop is an encoded
`string`, and a refused field's message names its spelled type.

### The hydrate point and the starter table — what front 68's entry calls

| Surface | What it does |
|---|---|
| `hydrate()` | the PER-ISLAND hydrate point: walks `[data-jh-i]`, finds that island's `i` row in the payload and starts the starter registered for its component in `globals.starters` (handing it the encoded props and a `commit(html)` that writes the island's markup); calls the loader registered for the payload's matched pattern (`r`) once, and runs again when it resolves; idempotent; mounts no link and no form |
| `registerStarter(name, start)` | one starter per client component — a second one fails, naming it, on both rows |
| `registerRouteStarters(pattern, load)` | one loader per route pattern (the manifest's `R` record): the route's chunk registers its own starters, so the bundle splits by route |
| `registeredStarters()` / `registeredRouteStarters()` | the table's names, in registration order |
| `propsFor(name)` | `propsOf` over the payload's first `i` row for `name` |

The table's name is the registry's fourth global (`globals.starters`, `__bp3`),
so the entry writes no `__` name and holds no host cell for it. All five cells
are dual-target (`island_runtime.mjs` / `sidecars/jhonstart_island.erl`, whose
registration reads back the same in the process dictionary and which never
calls a starter) — a called node-only cell reds the erlang build of the core
(27-a). What stays front 68's: every "may not" rule above (the walk over the
client module graph).

### One naming rule, and the checker defect that was behind it

**No local is named after an imported builder** (`p`, `a`, `li`, `text`,
`form`, `link`, `title` and `body` are all exported tag constructors). The rule
was forced: a local `val` leaked into the module scope the checker saw for
every top-level declaration after its body, so `val p = LikeProps(…)` in a
`test {}` redded a `@Component` component declared further down with `type
mismatch: expected Element, got LikeProps`. The checker now ends a local with
its body (`unbound variable 'v' — `v` is a local of `holder`, and a local ends
with its body`; measured 2026-09-26 with the compiler pinned for front 101), so
the rule is a reading convention, and the files that state it say so.

### Known defect — the `.mjs` sidecar is resolved by name, not by the dependency

The sidecar is shipped by `botopink build` (`shipMjsSidecars`, botopink-lang
`modules/compiler-cli/src/cli/libs.zig`) from whatever `libDirByName` answers for
the owning lib name across the **library roots** — never through the resolved
`{ "jhonstart": { "workspace": true } }` dependency the build already has in
hand. A miss is **silent**: the build still exits 0, `out/jhonstart/client_runtime.mjs`
is simply absent, and only `node client.mjs` fails. Owner: front
`00 · 10-cli-residuals`; the fix is to ship from the resolved dependency
directory. Never bypass a gate over it.

Measured on 2026-09-21 with the `zig-out` binary of `botopink-lang` feat, by
appending a distinct marker line to each candidate `client_runtime.mjs`,
building `examples/jhonstart-counter` and grepping the built `out/`. Every row
exits 0 — the sidecar's presence is the only observable:

| Layout, and where `botopink build` runs | Sidecar | Why |
|---|---|---|
| **before** — the flat package (`src/` at the root), no other checkout on the roots | **NOT shipped** | the root's manifest is a *package*, so `rootsFrom` never adds the directory itself; nothing on the roots is named `jhonstart` and `libDirByName` returns `null` |
| **after** — this layout, no other checkout on the roots | **shipped**, from `modules/jhonstart/src/` | the root's manifest is a *workspace*, so `rootsFrom` adds it and `scanRoots` contributes its members: one entry named `jhonstart` |
| **after** — `repository/jhonstart/examples/jhonstart-counter/`, the shape this lands as on `feat` | **shipped**, from `repository/jhonstart/modules/jhonstart/src/` | the enclosing workspace is a root and `repository/` reaches the same directory; `addUnique` de-dups by directory, so still one entry |
| **after** — a `.tasks/` worktree beside a `repository/jhonstart` that also declares the name `jhonstart` (migrated or not) | **NOT shipped** | two entries named `jhonstart` from two directories → `resolveDuplicateNames` marks both *declared by two libraries* → `libDirByName` skips an entry with a `problem` → silent miss |

So the move to `modules/jhonstart/` **fixed** the sidecar for a standalone
checkout and for the shape that lands on `feat`, and the old
`BOTOPINK_LIB_ROOTS` workaround (a real directory literally named `jhonstart`
with a symlinked `src/`) is obsolete: front 02-packaging step 1 replaced the
directory-basename lookup with a lookup by manifest name. What remains is a
worktree-only collision — while a `.tasks/` worktree and the main checkout both
declare the name `jhonstart`, `botopink-lib-test` reports
`"jhonstart" is declared by two libraries: …`, the sidecar is skipped in the
worktree, and `node client.mjs` there needs it copied by hand:

```sh
( cd examples/jhonstart-counter && botopink build \
  && cp ../../modules/jhonstart/src/client_runtime.mjs out/jhonstart/ \
  && node client.mjs )
```
