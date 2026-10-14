# jhonstart · CHANGELOG

## Unreleased

- **PK-5: `modules/jhonstart` and `modules/jhonstart-link` are `botopink format`
  clean** (front 101) — one reformat-only commit, 28 files, every cell at its
  count — except `modules/jhonstart-link/src/link.bp`: the formatter rewrites
  its record-update spreads `LinkProps(..p, …)` to `LinkProps(..: p, …)`, which
  the parser refuses, so that file waits on the printer (`112-gate-format`).

- **`repro/` is gone** (front 101): its four jhonstart-free reproductions are
  closed in the compiler — `erlang-imported-fn-field` green on both targets,
  `local-binding-leaks-to-later-decls` and `self-param-free-fn` now refused
  (`unbound variable`, `self-param-outside-type`), `erlang-std-slice-shim` no
  longer compiles against the current `querystring` — and its README said each
  is deleted when its fix lands. A defect is handed on as a cell the gate runs.

- **The repository's own gate is hard** (front 101, gate-i and gate-j): the
  pre-commit hook fails when no compiler is found (with the way out) instead
  of warning and skipping; a staged `*.snap.new` / `*.snap.md.new` is refused
  and `.gitignore` lists both; the `scripts/known-broken-examples.txt` branch
  is gone — an example that does not build fails the gate. CI runs
  `botopink-lib-test --target <t>` over the whole workspace (every member and
  every example a row) instead of the core member only, with no `allow_fail`
  key, and the examples and refusals gates on every row.

- **`jhonstart-dom-test`'s `commonJS`-only restriction is structural** (front
  101, gate-d): `src/root.bp` gains `callFill(name, id)` and `callSignal(name)`
  over the raw `call` cell (now module-private), so compiled code — not only
  test blocks — calls a node-only cell and `botopink build --target erlang`
  refuses the member with the host-binding error at `src/root.bp:37`. The
  suite is unchanged in what it asserts (9/9 on commonJS).

- **`jhonstart-counter` and `jhonstart-todo` run on both rows** (1.0.11-beta
  front 101, gate-a): the `"targets": ["commonJS"]` narrowing is gone from both
  manifests — the two erlang reds it hid (a bare `print(…)`, a `fn`-typed field
  called across a module boundary) are fixed in the compiler, and the cells pass
  on erlang (4/4, 3/3).

- **The `query` hole is closed** (`03-rakun` front 22 / `04-jhonstart`):
  `PageContext` loses its `query` field; `searchParams()` and `request()` mark
  the render dynamic through a flag in the router's host store, and the
  payload's `d` reads it instead of a constant `true` — a boundary's mark rides
  back from its own erlang process on `Resolved.dynamic`. `jhonstart` 199 →
  204 on both rows.
- **`jhonstart-link`'s `with*` helpers use the record update form**
  (`LinkProps(..p, prefetch: prefetch)`), and the notes that `check` skips
  decorators and that an imported default is not applied are gone: both hold
  no longer on the compiler.

- **`jhonstart-dom-test` — front 30's browser half, asserted** (commonJS only):
  the fill and signal functions `render.mjs` registers and `readPayload`, run
  against a minimal document installed from the render's own markup. 9/9.

- **The example projects** (`modules.md` § 8, `test-snap-examples.md`):
  `blog-ssr`, `nav-shell`, `islands`, `forms` and `document-shell` (every
  one green on both rows, so every one declares both), 32 snapshots through `jhonstart-test`, each compared with
  the spec's literal. The aspirational `examples/jhonstart-app` sketch is
  removed — `blog-ssr` is what it described.

- **`jhonstart-test` — the helpers** (`modules.md` § 5, `test-snap.md` § 0.2):
  `harness.bp` (fixtures, `renderToStream`, `simulateNavigation`, the recording
  `Response` with `renderRecorded` / `renderStreamCollect`) and one
  `assert_<subject>.bp` per front, each `assert<Subject>` over std's
  `snapshots.assertAs` with a pure `<subject>Text` twin. `helpers_test.bp`
  asserts every twin against the spec's literal and records seven snapshots.
  1 → 21 on both rows.

- **What onze owed from jhonstart** (fronts 29 and 30): the island starter
  table is the registry's fourth global, `globals.starters` (`__bp3`), filled by
  `registerStarter(name, start)` (one per component) and
  `registerRouteStarters(pattern, load)` (one loader per route, called once by
  `hydrate()` for the payload's matched pattern — the bundle splits by route);
  onze's entry writes no `__jhIslandStarters` of its own. `app(…, lang:)` sets
  the document's `<html lang>` (`"en"` when not given; a value that is not a
  language tag is refused) where `lang="pt-BR"` was a literal. The render over
  rakun's `ChunkWriter` (contract 5d) is asserted with a record spelled field for
  field and adapted as onze does: a page, a pre-first-chunk redirect and a
  pre-first-chunk `notFound()`. Core 190 → 199 on both rows.

- **Front 67 — forms**, the new member `modules/jhonstart-forms` (additive):
  contract 3's form markup (`formAttrs`, `hiddenActionField`), the transport
  (`submitForm`, `invokeAction`, `formMount`) over six dual-target cells, the
  `actionState` / `formStatus` / `optimistic` hooks with their quiet server
  pass, `applyOptimistic`, and the GET search form. `ActionState`,
  `parseActionState` and `writeRpcBody` are imported from the bundled
  `actions`; the wire names come from onze through `setWireNames`. 15/15 on
  both rows.

- **Front 29 Step 4 — the hydrate point.** `hydrate()` (idempotent: walks
  `[data-jh-i]`, starts each island's registered component with its payload
  row, binds `[data-jh-reset]`) and `propsFor(name)` over two dual-target cells
  (`island_runtime.mjs`, `sidecars/jhonstart_island.erl`). The core's `files`
  list moves `globals.bp` before `client.bp`, which now imports it. Core
  185 → 187 on both rows.

- **Front 27 Step 4 — the link's browser half** (`jhonstart-link`):
  `linkMount()` (one delegated click listener + a viewport prefetcher,
  idempotent), `linkPrefetch`, `linkRouteKind` and the `linkStatus()` hook
  over four dual-target cells (`link_runtime.mjs`, `sidecars/jhonstart_link.erl`
  answering the server's idle truth). `jhonstart-link` 35 → 38 on both rows.

- **Front 26 Step 6 — `clientApp`** (`client_app.bp`, decision 117): a
  client-only app matches the location with `routing`, composes the matched
  chain through front 30's `compose` and writes it into `mount`; `notFound` /
  `redirect` are handled in the browser as the server render handles them,
  with the same target check. Core 181 → 185 on both rows.

- **Front 30 — render and streaming.** `render.bp` (the escaping walker over
  std's `escape`, `compose`, the payload through std's `json` and
  `escape.scriptJson`, `RenderHooks`), `streaming.bp` (`resolve` / `fillHtml`,
  `Response` and its guard, `App.render` / `renderStream` →
  `@Task<@Result<void, string>>`, navigation signals before and after the first
  chunk, the redirect-target check), `suspense.bp`, `plugin.bp`, `globals.bp`,
  `routes.bp` (`#[page]` / `#[layout]` / `#[template]` / `#[defaultView]`,
  `uiTable()`, `UiSegment`) with their host halves, and the new member
  `modules/jhonstart-emilia` (the bridge — additive). The core's `files` list
  is now in DEPENDENCY order: a dependent loads the modules in that order, and
  a module listed before one it imports is `unbound` there. Core 128 → 180 on
  both rows; `jhonstart-emilia` 6/6 on both.

- **Front 95 — the package cut: `jhonstart-link` member.** Front 27's
  render-time half — `link.bp` and `reconcile.bp`, with `link_test.bp` and
  `reconcile_test.bp` — moves out of the core into `modules/jhonstart-link/`
  (`from "jhonstart-link"`), as `specs/1.0.10-beta/04-jhonstart/modules.md` § 1
  cuts it. A relocation only: the one edit per file is `from "element"` →
  `from "jhonstart"` in `link.bp` and `link_test.bp`; `reconcile.bp` keeps its
  sibling import of `link`. Nothing in the core imported either module. The
  member inherits `[commonJS, erlang]` (the code is pure). The core reads 85/85
  on both rows where it read 120, the member 35/35 on both rows.

- **Front 32 — metadata** (`metadata.bp`). `Metadata` / `OpenGraph` /
  `TwitterCard` / `Icons` and a separate `Viewport`, the merge rule (strings
  replace when non-empty, lists wholesale, records field by field, the
  parent's `titleTemplate` applied once to the child's title), and
  `renderHead` / `renderViewport` writing one tag per line in a fixed order
  through std's `escape`. Core 147 → 163 on both rows.

- **Front 31 — error boundaries** (`error_boundary.bp`). A boundary's child is a
  `@Result` thunk called exactly once through `__jhCapture`, the one host cell
  that turns a raise into a value (`signal_runtime.mjs` /
  `sidecars/jhonstart_signal.erl`); an ordinary failure renders the fallback
  with a message-free `ErrorInfo` whose digest is std's `contentHash`, a
  signal is re-raised (`renderBoundary`) or answered `Error(reason)`
  (`renderBoundaryChecked`). `notFound()` / `redirect(url)` raise `routing`'s
  `nav:` reasons. `root.bp` and `files` now list the modules in front-number order
  (26, 28, 29, 31, then 94's `elements` last — front 94's rule). Core 128 → 147 on both
  rows.

- **Fronts 27 and 29 — decision 113's spellings.** Every marker jhonstart
  writes carries the `data-jh-` prefix: the link's `data-jh-l` /
  `data-jh-prefetch` / `data-jh-replace` / `data-jh-scroll`, the island's
  `data-jh-i`, the hole's `data-jh-s`, the handler's `data-jh-on-click`; the
  browser cells front 68 brings are named `__jhLink*` / `__jhClientPropsRaw`.
  No `data-onze-` string is left under `modules/*/src/`. One new cell: a
  `#[client]` on a plain `-> Element` component. Core 127 → 128 on both rows.

- **Fronts 26 and 28 — decisions 115 and 116 in landed code.** The package's
  stand-in pair codec (`decodePairs` / `encodePairs`, which did not
  percent-decode) is deleted: the route snapshot, the request and an island's
  props use std's `encoding.formParse` / `formStringify`, so `q=a%20b` reads
  `a b` on both rows. `refresh()` carries `actions`' `refreshValue()`;
  `navigationFor` / `applySignal` read an envelope's `n` with `routing`'s
  `signalFromWire`; `resolveRoute(table, path, search)` rebuilds the snapshot
  with `routing`'s `parseTable` / `matchPath`. The request's writer is the pair
  `enterRequest(req)` / `leaveRequest()` (was `fillRequest(…six strings…)`),
  and a `request()` / `cookies()` / `headers()` read outside them raises.
  Core 120 → 127 on commonJS and erlang.

- **Front 24 — effects by return type** (botopink decisions 118–128). The
  return type is the effect and the `#[@use]` / `#[@future]` annotations leave:
  every hook and component keeps its `-> @Component<ElementBase, T>` return and
  loses the annotation line; every data-loading server component, loader and
  render entry that returned `@Future<T>` returns `@Task<T>` —
  `renderServerComponent(component: fn() -> @Task<Element>) -> @Task<string>`,
  `renderComponent(component: fn() -> @Component<ElementBase, Element>) -> @Task<string>`.
  No `@Future` here carried an error and no body throws, so every Task is a plain
  `@Task<T>` and every `await` stays a bare `await` — no `try await` was needed
  in the compiled members. The aspirational `examples/jhonstart-app` sketch (not
  a member, not built) shows the new failure rule instead: its loader is
  `@Task<@Result<…, string>>` over `try await fetch(…)`, and its page, a
  component returning `Element`, handles the failure with `try await … catch …`
  rather than propagating it (decision 121). `docs.md` § *Server components*
  gains the same rule and example; the recorded compile errors in
  `test/server_test.bp` and `docs.md` are the front-24 codes
  (`effect-await-without-task`, `use-without-context-effect`,
  `effect-try-without-fallible-channel`, `effect-annotation-removed`). Four test
  names spell `@Task` / `@Component` instead of the annotation. The `#[client]`
  refusal now names the data-loading component's reflected `"Task"`.
  `client_test.bp`, `server_test.bp` and `examples/jhonstart-counter` import
  `ElementBase`, which they named without importing since the decision-128
  re-spelling — the reason both core rows and the counter's commonJS row did not
  compile at `feat` (120/120 and 4/4 once they do).
  Measured against botopink-lang `front/24-effects-by-return` `86609a66`:
  `jhonstart` 120/120 on commonJS and erlang, `jhonstart-html` 5/5, `jhonstart-markup`
  7/7, `jhonstart-test` 1/1, `jhonstart-todo` 3/3 on both rows, `jhonstart-counter`
  4/4 on commonJS (its erlang row stays the pinned `set/2` defect); every hook,
  component and `@Task` fn still lowers to an `async function` on commonJS. The
  four compile errors recorded in `test/server_test.bp` were reproduced by code.

- **Front 95 — the package cut: `jhonstart-html` and `jhonstart-test` members.**
  The `html """…"""` DSL leaves the core for its own member
  `modules/jhonstart-html/` (`from "jhonstart-html"`), with the two suites that
  exercise it from a consumer's position (`html_test.bp`, `elements_test.bp`);
  its one edit is `import {Element} from "jhonstart"`. The core no longer
  depends on the DSL and reads 120/120 on both rows (was 125 — the five moved
  tests are the member's 5/5). `modules/jhonstart-test/` is created empty with
  one inline test, for the track-C fronts to fill. The example
  `examples/jhonstart-html/` is renamed `examples/jhonstart-markup/`: a member
  name is unique in the workspace and the DSL member takes it. A consumer of
  the DSL now writes `import {html} from "jhonstart-html";` beside
  `import {div, p, text} from "jhonstart";`.

- **botopink front 21 — the effect chain (decisions 102–104).** `Element`
  implements the owner marker `@Context<ElementBase>` (a phantom
  `type ElementBase`), every hook is `#[@use] fn … -> @Component<ElementBase, T>`,
  every component that activates a hook is `#[@use] fn … -> @Component<ElementBase, Element>`
  (one that activates none — `Link`, `NavBar` — is an ordinary `fn … -> Element`),
  and `request()` is a hook. A `#[@future]` body no longer activates a hook
  (decisions 89/90 revoked): the server component that uses and awaits is
  `#[@use] … -> @Component<ElementBase, Element>`, rendered by the new `renderComponent`.
  On commonJS every `#[@use]` body is an `async function`, so a test or a
  `#[@future]` body `await`s a hook or component it calls without `use`.
  `#[client]` accepts `@Component<ElementBase, Element>`. Counts unchanged on both rows.

- **Front 29 — the server/client boundary: `client.bp`.** Next.js `'use client'`
  is a string literal the bundler reads; botopink has no directive syntax and
  the milestone forbids compiler changes, so the boundary is built out of
  annotation processing: `#[client]` marks a component, `#[clientProps]` marks
  the record its props travel in, and the server render contributes an
  **island** — `<div data-onze-i="i0">` — whose component name and encoded props
  live in front 23's payload rather than on the element. The file is **pure**:
  it declares no host cell of any target, so all 22 new assertions run on
  **both** rows and an island renders during the server pass exactly as it
  renders in the browser. The member goes 103 → **125** on each row.
  - **Front 29 defines the boundary; front 68 enforces it.** The front's
    priority line is a security claim, and this commit does not land it. What is
    enforced today is four comptime REFUSALS with no flag that turns them off
    (decision 67): `#[client]` on a non-`fn`; `#[client]` on a fn whose reflected
    `returnType` is not `Element` (a `#[@future]` server component reflects as
    `"Future"`, so it cannot be marked client); `#[clientProps]` on an
    enum-shaped `type`; a field outside the whitelist, named with its type. What
    is **not** enforced by anything in this tree: that a `#[client]` component's
    parameter record carries `#[clientProps]` at all (`@Decl` exposes no
    function parameters), that no module reachable from a client component
    imports `serverOnly` or `request`/`cookies`/`headers`, and that the props
    written into an island's `i` row are the ones the record declares. All three
    are module-GRAPH predicates. Today a secret read on the server still reaches
    the browser if it is written into an island's props, and nothing here
    notices; `client.bp`'s header, `AGENTS.md` and `docs.md` all say so rather
    than implying the decorator is a sandbox.
  - **The emitted marker is a PURE function.** `#[client]` emits
    `pub fn __jhClient_<Name>() -> string`, not a call into a runtime registry:
    an `@emit` fires on EVERY target, so emitting a call into a Node-only cell
    would make every `#[client]` component fail to link during the erlang server
    render — the exact case the boundary exists to support. The `@emit` comes
    before the `fail` checks, matching rakun's ordering, so a misplaced
    declaration wires up nothing. `botopink check` skips decorator invocation
    entirely and reads the emitted name as unbound; the gate is `botopink test`.
  - **The whitelist is four names and not the spec's six.** § Step 2 asks for
    `string[]` and `i32[]` too, and `Field.typeName` cannot express either.
    Measured against compiler `2e6bb4ac` over one record carrying a field of
    each shape: `Array<string>` and `Array<Element>` both reflect as `"Array"`
    (the element type is erased), and `string[]`, a function type and a tuple
    type all reflect as `""`. Admitting `"Array"` would admit an array of
    `Element`s through a check whose whole purpose is to refuse exactly that, so
    the refusal wins: no array crosses today and an array-valued prop is spelled
    as an encoded `string`. The front's first § Language gaps row widens from
    "no parameters on `Decl`" to "no ELEMENT TYPE on `Field`".
  - **Decision 77 — one definition, passed in.** `islandAttrOf(id)` is the only
    occurrence of `"data-onze-i"` in this tree; `islandId(ordinal)` is the only
    spelling of an island id; `islandAttr(ordinal)` composes the two and is what
    front 23 fills `RenderHooks.islandAttr` from and what front 68's generated
    entry imports. It must be passed as a **lambda** — `{ n -> islandAttr(n) }`
    — because a bare function name used as a value lowers to an unbound erlang
    variable, and the field must be read into a local before it is called.
    `serverSlotAttr()` gets the same treatment for `data-onze-s`.
  - **`clientMount` carries the id and nothing else**, and `islandEntry` is the
    payload's `i` row `#(id, component, "k=v&k=v")`. Putting the name and the
    props in the payload rather than on the element is what makes the boundary
    auditable: every crossing value is in one place, in render order, and front
    68 can walk it. The encoder is front 26's `encodePairs` and not
    `std/querystring.stringify`, which the spec asks for and which is dead on
    the erlang row — one encoder in the package, the same argument `pairValue`
    makes about decoders. It does not percent-encode; a prop value containing
    `&` or `=` does not round-trip, and that is front 26's codec to widen.
  - **`serverSlot` marks the hole.** A client provider may wrap the whole
    server-rendered tree; the subtree inside `data-onze-i` is server markup the
    client must ADOPT and must not re-render, because re-rendering it would need
    the server's data and the server's secrets. `Element` is deliberately off
    the whitelist for the same reason: server output reaches a client component
    as CHILDREN, never as a PROP.
  - **`hydrate()` and `propsFor(name)` are absent, not stubbed.** Both name
    front 68's generated module `jhonstart/client-runtime`, which does not
    exist. Re-measured for this file: a **called** node-only cell reds the
    ERLANG build at its call site and this module is compiled on both rows, so a
    `propsFor` wrapper would take every landed assertion off erlang; a
    **declared and never called** one is fine, but the module it names would
    emit a `require` of a file nobody writes. What ships instead is `propsOf`,
    the whole pure decode `propsFor` performs — `propsFor` is then two lines.
    Three acceptance rows are declared unassertable in the test-file header with
    the reason and the exact front that supplies them.
  - **New compiler defect, measured and reported, not worked around.** A local
    `val` declared in one top-level body stays visible to the CHECKER in the
    body of every top-level declaration that appears after it in the same
    module: the name compiles where nothing declares it (and dies `v is not
    defined` at run time, `variable 'V' is unbound` at `erlc`), and it SHADOWS a
    function of the same name, rejecting a correct call site with a type
    mismatch naming a record that call never mentions — with no line and no
    column. Order is the whole defect. Twelve jhonstart-free lines in
    [`repro/local-binding-leaks-to-later-decls/`](repro/local-binding-leaks-to-later-decls/),
    owner `00 · 01-checker`.
  - `pub mod client;` and the `files` entry are appended here, as fronts 26, 94,
    28 and 27 each appended their own. The front's § Step 5 and § *Does not
    touch* say both lines are HANDED to front 94; front 94 is closed and there
    is nobody to hand them to. Recorded in `AGENTS.md` as a spec/tree
    disagreement.

- **Front 27 — client navigation: `link.bp` and `reconcile.bp`, the render-time
  half.** `router.d.bp`'s one-line `declare fn Link` explained why it never
  became real — "`Element` … has NO attribute slot … a real `.bp` `Link` would
  silently drop `href`". That reason expired with `element.bp`'s `attrs`, and
  the anchor is now ordinary botopink. Both files are **pure**: they declare no
  host cell of any target, which is stronger than the front's "no
  `#[@External.Erlang]` cell" acceptance row, so all 35 new assertions run on
  **both** rows and `Link` renders in the server pass exactly as in the browser.
  - **`LinkProps` + `linkProps(href)` + five `with*` helpers.** The props are a
    record because `Link(href, children, prefetch = true, …)` does not work for
    a consumer — see the measurement below. `linkProps` fills Next's documented
    defaults; each `with*` returns a NEW record and none assigns to a field of
    its argument, there being no copy-with-update expression.
  - **`#[@context] Link(props, children) -> Element`** — `<a href=…
    data-onze-l="1">`, plus one attribute per prop that DIFFERS from its
    default, so a page with two hundred links does not carry five redundant
    pairs on each. `target` and `class` are real attributes; `prefetch`,
    `replace` and `scroll` are `data-onze-*`. There is no pass-through `attrs`
    parameter: an anchor that accepts any attribute is an anchor that can be
    handed its own `data-onze-l`, the marker the browser half queries on.
  - **`prefetchMode(kind, hasLoading, requested)`** — `NEXTJS-DOCS.md § 8`'s
    table verbatim, as a pure function so that it is testable without a
    browser. Both inputs are front 60's; jhonstart computes neither. An unknown
    kind is not static, so it falls through to the boundary question and
    answers `skip` — the conservative answer a missing table should produce.
  - **`layoutKey` / `layoutKeys` / `sharedDepth`** — a layout is keyed by its
    segment PATH, never by its position in the tree, so two routes under
    `/docs` reuse the docs layout and a route under `/blog` does not. The keys
    come from front 26's `RouterState.segments()`, so the key a client
    transition computes and the key the server rendered under are the same
    string. `sharedDepth` is never `0`: the root layout is never remounted.
  - **`LinkStatus` / `linkStatusOf(href)`** — the pure derivation the
    `linkStatus()` hook will return, `""` being idle.
- **The browser half is NOT shipped, and is not stubbed.** `__onzeLinkMount`,
  `__onzeLinkPrefetch`, `__onzeLinkStatus`, `__onzeLinkRouteKind`,
  `linkStatus()` and the transition driver `reconcile(current, target)` all wait
  on fronts that have not started: **front 68**'s generated client bundle (the
  module the four cells bind to, and the DOM primitives the driver mounts and
  unmounts through) and **front 60**'s route-kind table. Two measurements make
  writing them today wrong rather than merely early, and they point in opposite
  directions:
  - **A called node-only cell reds the ERLANG build at its call site.** Measured
    2026-09-21 against compiler `2e6bb4ac`: `pub fn statusOf() { return
    __cellStatus(); }` over a `#[@External.Node]`-only cell builds on commonJS
    and fails erlang with ``error: `__cellStatus` has no
    `#[@External.<Target>(…)]` for the erlang backend``. It is the mirror of the
    erlang-only → commonJS measurement fronts 26 and 28 both carry, and it
    applies because these modules land in the core member, compiled on both
    rows — a `linkStatus()` wrapper would take all 103 assertions off erlang.
  - **A declared and never-called node-only cell is fine** (re-measured; it is
    why `client_runtime.bp`'s `clientRender` does not red erlang). What is not
    fine is the module it would name: `jhonstart/client-runtime` does not
    exist, so the declaration would emit a `require` of a file nobody writes.
    A host cell answering what no one can check is exactly what `router.d.bp`'s
    one-line `Link` was, and the reason it never became real.
- **Measured: an IMPORTED declared default is still not applied.** A trailing
  default is filled at the call site for a declaration in the calling module
  (C-04); across a package boundary it is not. On both rows — it is a checker
  answer, so every target fails identically — against jhonstart's own `text`:

  ```text
  import { text } from "jhonstart";  text("hi")
  error: 'text' expects 2 argument(s), got 1
  ```

  This is why `Link` takes a record and not six parameters with five defaults,
  and it is the front's first § Language gaps row. The second — no
  `Record(base, field: value)` copy-update — is what makes each `with*` helper
  respell all six fields.
- **Spec vs. landed tree, recorded not resolved.** The front table and
  `modules.md` put `link.bp`/`reconcile.bp` in a submodule `jhonstart-link`,
  while front 27's own README § Owns says `repository/jhonstart/src/link.bp`
  (the flat 1.0.9 layout). The landed tree has exactly one member,
  `modules/jhonstart/`, and no submodule split has happened yet — `html.bp` is
  still in core too — so both files land in the core member. And § Step 5 says
  the `root.bp` / `botopink.json` lines are HANDED to front 94, while fronts 26
  (`d9f1f3c`), 94 (`dc979b6`) and 28 (`6d6c007`) each appended their own; front
  27 follows the tree.
- **Counts.** `modules/jhonstart` goes 68/68 → **103/103 on both rows** (25 in
  `test/link_test.bp`, 10 in `test/reconcile_test.bp`), summing the per-module
  summaries — `botopink test` prints one PER MODULE, so its last line is the
  last module's count and not the run's total.

- **Front 28 — server components: `server.d.bp` is promoted to `server.bp`.**
  The declaration file listed three blockers and all three are answered rather
  than carried.
  - **`RequestData`** — six fields (`method`, `path`, `params`, `query`,
    `headers`, `cookies`), every plural one `Array<#(string, string)>`: the
    shape front 26's snapshot uses, the shape `decodePairs` produces and the
    shape `Element.attrs` takes, so a value read off the request reaches an
    attribute with no conversion. No `Dict` (naming `dict.Dict<string, string>`
    across a module boundary is unexercised anywhere in this tree) and **no
    `body` field** — a render never reads one; form bodies are front 24's and
    route-handler bodies front 25's.
  - **Four accessors that cannot fail** — `param`, `queryParam`, `header`,
    `cookie`, each a plain `string` and `""` when absent. All four funnel
    through front 26's `pairValue`, so "the value of `slug`, or the empty
    string" cannot mean two things in one package. Field names and method names
    are disjoint, the rule `RouterState` already follows.
  - **`request()`, `fillRequest()`, `cookies()`, `headers()`** over six host
    cells, plus `renderServerComponent(component) -> @Future<string>` — one
    `await`, then a synchronous render, over an **unstarted thunk**
    `fn() -> @Future<Element>` so that a page which grows a second loader moves
    to front 02 without changing what it hands anybody.
  - **The `Http` phantom `@Context` base and the `Request` behavior are gone.**
    Decision 89 unwraps `@Future<Element>` to the owner `Element`, so one base
    serves the whole render tree and a memberless second base would be a base
    nothing implements. `AGENTS.md` § *The `Http` base, and why it is gone*.
  - **The async data layer is no longer gated.** `#[@future] fn … -> @Future<T>`
    with a statement-level `await` compiles and RUNS on both rows, `test` blocks
    included — measured, not assumed.
- **The six cells are jhonstart's own, dual-target, with both host halves
  shipped** (`src/server_runtime.mjs`, `src/sidecars/jhonstart_server.erl`) —
  the spec binds them to front 62's `rakun_request_context` with no Node cell,
  and neither half is writable. Measured against compiler `2e6bb4ac`: an
  erlang-only cell reds the **commonJS compile** at its call site (`` `__jhReqMethod`
  has no `#[@External.<Target>(…)]` for the node backend ``), taking the whole
  core member down on a row it is not even gated on; and `rakun_request_context`
  has no BEAM row to bind to at all, because rakun's member is
  `targets: ["commonJS"]`, so on erlang — this front's *assigned* target — every
  cell would answer `{error,undef}` and no assertion that reads the request
  could run. So the seam is here and it is `pub`: `fillRequest` is the one
  writer and front 62's dispatcher calls it once per request. Front 26 reached
  the same conclusion for the route snapshot and for the same reason.
- **`decodePairs`, not `querystring.parse`.** `libs/std/src/querystring.bp` is
  dead on the erlang row — reached through `from "std"` it emits a bare local
  `slice/3` it never defines. Re-measured 2026-09-21 against `2e6bb4ac`;
  `repro/erlang-std-slice-shim/` is the jhonstart-free package. One decoder in
  the package, which is the argument `pairValue` already makes.
- **Measured: a bare function name used as a value is unbound on erlang.**
  `renderServerComponent(Page)` compiles on commonJS and fails
  `variable 'Page' is unbound` on erlang; `{ -> Page(ps) }` is green on both.
  A compiler defect, reported rather than worked around, and the same shape
  rakun's front 23 records for the fields of its `ElementView`. Every call site
  in this package spells the lambda.
- **Measured: decision 90 works.** A `#[@future] fn … -> @Future<Element>` body
  activates a hook (`val here = use pathname()`) with **no** `#[@context]`
  beside it, green on both rows. R5 is what makes that necessary rather than
  convenient: `#[@future] #[@context]` is `effect-duplicate-annotation`. A
  *client* component still carries `#[@context]` (decision 88) — a plain
  `fn … -> Element` that writes `use` is `use-without-context-effect`.
- **What front 28 deliberately does not ship.** No escaping — front 01's
  `escape.html` / `escape.attribute` do not exist in `2e6bb4ac`, and a stand-in
  here would be a second answer to "what is an escaped `&`" the day they land;
  the suite PINS the unescaped answer so the change is a red cell. No
  `awaitAll`/`race`/`allSettled` — `@Future` is eager on erlang
  (`libs/std/src/http.bp:16-18`), independent loaders awaited in sequence cost
  the **sum** of their round trips, and the fix is front 02's spawn-and-gather
  over unstarted tasks. No `ElementView<Element>` adapter — front 26's
  `AGENTS.md` hands it here, front 28's own spec does not ask for it, and the
  structural obstacle front 26 recorded has not moved.
- `docs.md` gains § *Server components (`server.bp`) — compiled`, and its *App
  layer* and *V1 limits* sections lose the stale "gated" rows.
- The core member measures **68/68 on both rows** (51/51 before front 28). All
  17 request assertions RUN on the erlang row — none is type-checked-only and
  none is a commonJS-only claim.

- **Front 26 closeout — `encodePairs`, and what fronts 27–32 consume.**
  - `encodePairs(pairs) -> string` is `decodePairs` reversed and ships for the
    same reason: `querystring.stringify` has no `slice` of its own, but it
    lives in the module `stripPrefix` kills, and a module `erlc` refuses takes
    its whole surface down with it. Every front downstream that rewrites a URL
    needs an encoder, and one encoder in the package is the argument
    `pairValue` already makes about decoders. No leading `?` — the caller adds
    it.
  - `AGENTS.md` gains § *What jhonstart fronts 27–32 consume from front 26* —
    the whole surface, the two call-site rules that only show at a distance,
    and the three things front 26 deliberately does **not** provide (a second
    matcher, the `ElementView` adapter, a `Link`).
  - The adapter rakun front 23's handoff assigns to "front 26" cannot be
    written here: `ElementView<El>` is rakun's type, jhonstart declares no
    dependency on rakun, and rakun's member is `targets: ["commonJS"]`, so
    adding one would red the very row front 26 is assigned to. It belongs to
    **front 28**, with the `dependencies` entry and the targets decision that
    entry forces. Recorded in `AGENTS.md`, not worked around.
  - Front 26's position on the `query` hole front 23 measured and left open is
    in the same section: the front **needs** the guarantee, a convention cannot
    close it, and the three things that would are all front 22's file. This
    library's `searchParams()` reads its own snapshot and never touches
    `PageContext`, so nothing here papers over it.
  - The core member measures **51/51 on both rows** (27/27 before front 26).
    All 24 router assertions RUN on the erlang row — none is type-checked-only
    and none is a commonJS-only claim. The CI table's earlier `9/9` was stale:
    it predates `elements.bp`.

- **The six navigation verbs (front 26, step 4).** `push`, `replace`, `back`,
  `forward`, `refresh` and `prefetch` — free functions over one dual-target
  cell, never methods: botopink records are immutable and there is no
  assignment to a `self` field anywhere in this tree, so the record stays a
  read-only snapshot and navigation is a call against host state. `-> i32` is
  the ecosystem's shape for a host value nobody reads.
- **`lastNavigation()` is `pub`.** `push("/x")` on the erlang row *records* a
  307 for the dispatcher to write; a verb that records where nobody can look is
  a verb that does nothing, so the recorded `"<kind> <href>"` is readable. Both
  halves record, so the same three assertions run on both rows and "callable
  on the erlang target without a host stub crash" is an execution, not a
  compile.
- The front's spec says `__jhNavigate` is the only dual-target cell in the
  file. It is not, and the reason is step 2's measurement rather than a
  preference: every cell here carries both targets because an erlang-only cell
  reds the commonJS row at its call site.
- 3 further assertions, green on both rows (22 in the suite).

- **The six route hooks (front 26, step 3).** `router`, `pathname`, `params`,
  `searchParams`, `selectedLayoutSegment` and `selectedLayoutSegments`, each
  `pub fn … -> @Context<Element, T>` and each one read of `snapshot()` and
  nothing else — a hook that did work of its own would be a second place for
  the route to be interpreted. Nouns, never `useRouter`, never the doubled
  `use usePathname()`.
- **Measured: `use` is not decoration for an array-valued hook.** A hook called
  without `use` keeps its `@Context<Element, T>` type. That type is transparent
  to a property or a method (`ps.length`, `segs.join("/")`, `r.param("slug")`)
  and **not** to a typed parameter — `pairValue(params(), "slug")` is
  `type mismatch: expected array, got Context`, and binding through a `val`
  does not change it. Only `use` strips the capability: inside a `#[@context]`
  body `pairValue(use params(), …)` is exactly the array, and
  `test/router_test.bp`'s `ActiveNav` asserts the rendered markup to prove it.
  The front's spec says a hook "called WITHOUT `use` also type-checks and
  returns the [value]"; that holds for the two `string` hooks and not for the
  three array-valued ones.

- **The route snapshot has a host half on both rows (front 26, step 2).**
  `snapshot()` reads five cells and builds `RouterState`; each maps one-to-one
  onto a key of rakun front 23's payload envelope (`p`/`m`/`q`/`r`, plus the
  per-layout `selected`, which has no payload key). The two pair-shaped values
  travel querystring-encoded — no JSON, no record serialization, nothing that
  has to agree between an Erlang term and a JS object.
  - `src/router_runtime.mjs` (a module-global) and
    `src/sidecars/jhonstart_router.erl` (the calling process's dictionary) are
    the two halves, cell for cell, so `test/router_test.bp` is ONE set of
    assertions run on both rows. A request is a process on the BEAM, so the
    snapshot dies with it and two concurrent renders cannot see each other's
    route. Neither half parses or matches anything: the matcher and the route
    table are rakun front 22's, compiled once.
  - An unfilled snapshot answers `""`/`[]`/`0` rather than raising — rendering
    a component outside a request is how this package's own tests render the
    server pass.
  - **Every cell carries both targets**, where the front's spec asks for the
    five reads to be `#[@External.Erlang]` only. Measured: an erlang-only cell
    reds the commonJS row at its *call site* (`` `__jhRoutePath` has no
    `#[@External.<Target>(…)]` for the node backend ``) the moment `snapshot()`
    calls it, and this module is compiled on both rows of the core member. A
    declared and never-called cell is fine — which is why `client_runtime.bp`'s
    node-only `clientRender` does not red the erlang row. The dual form is also
    what the front's own mechanism needs: the client rebuilds the snapshot from
    the payload on every transition.
  - **`fill(path, params, search, pattern, selected)` is `pub` surface**, and
    the front's spec has no such function — it has rakun front 22 writing the
    request's process dictionary before dispatch. That cannot be how it works:
    jhonstart declares no dependency on rakun, rakun's member is
    `targets: ["commonJS"]` and has no BEAM row at all, and a server reaching
    into another library's process-dictionary keys would be coupled to them
    forever. So the seam is here. It is also what makes `snapshot()` assertable
    — the front's test plan asks for "`snapshot()` over a stubbed host module",
    and a stub you cannot seed is a stub you cannot assert.
  - 5 further assertions, green on both rows (16 in the suite).

- **The router is a compiled module (front 26 of 1.0.10-beta, step 1).**
  `src/router.d.bp` is deleted and `src/router.bp` takes its place in the build
  tree. The declaration file gave two reasons nothing in it was promotable:
  `Element` had no attribute slot, and client navigation lives in a host
  runtime. The first closed with `element.bp`'s `attrs`; the second was never a
  reason to keep the *record* host-bound.
  - `type RouterState(path, params, search, pattern, selected)` — a plain
    five-field record, **not** a behavior. A behavior with `val` members has no
    verified implementor anywhere in this tree, and the concrete record is what
    the `use` capability has to yield anyway. Its accessors are `param(name)`,
    `searchParam(name)`, `segments()` and `segment()`, and every one answers a
    plain `string`/`Array<string>` — `""` for an absent key, `""` for an
    out-of-range layout depth, never `?string`.
  - Field names and method names are **disjoint** (`params` the field,
    `param(name)` the method), so a field read never shadows a method.
  - `segments` is **derived** from `pattern` and never transported. The bracket
    spelling is kept: `"/blog/[slug]"` → `["blog", "[slug]"]`.
  - `pairValue(pairs, name)` is the package's **one** pair-list decoder, `pub`,
    answering the FIRST match of a duplicated key. Fronts 28 and 32 import it
    from here rather than each growing a copy.
  - `pairValue`, `patternSegments` and `segmentAt` are loops over typed
    parameters rather than `find(…)`/`at(i)` + `unwrapOr`: a value that came
    back through the optional binder loses its type on the erlang row, the
    measurement behind rakun's `paramOf(m, name)` and `chunkAt(page, i)`.
  - `test/router_test.bp` — 11 assertions, green on **both** rows.
- **`decodePairs` instead of `std/querystring.parse`, with the defect handed
  back.** `libs/std/src/querystring.bp:22` writes `query.slice(1,
  query.length)`. Reached through `from "std"` that module emits a call to a
  bare local `slice/3` on the erlang row and never defines it: `erlc` refuses it
  with `undefined_function {slice,3}`, the test runner's sibling loader skips a
  module that does not compile, and the first `querystring.parse` call dies
  `{error,undef}` — pinned to the caller, not to the module that failed. The
  same `s.slice(a, b)` in a project module lowers correctly to an emitted
  `string_slice/3`, so the loss is specific to a `libs/std` module compiled as a
  dependency (`String.slice` is a primitive-interface `default fn`, and
  `collectPreludeInstanceDefaults` is guarded by `comptime_module != null`).
  erlang is front 26's assigned target, so `router.bp` carries `decodePairs` —
  querystring's documented behaviour, spelled in a project module, collapsing
  back to `querystring.parse` the moment the shim lands.
  `repro/erlang-std-slice-shim/` is the jhonstart-free package.
- **`src/root.bp` gains `pub mod router;` and `botopink.json`'s `files` swaps
  `router.d.bp` for `router.bp`** — the two lines front 94's spec already
  reserves for front 26, appended in front-number order, no other line touched.
  Without them `src/router.bp` is *module not reached by any `mod` path — not
  compiled* and `test/router_test.bp`'s import is refused, so the front has
  nothing to be green about.

- **`jhonstart-counter` and `jhonstart-todo` on the erlang row — one library
  error fixed, one compiler defect handed back.** The compiler's new
  `scripts/restricted-targets.txt` runs every cell a member's `targets`
  excludes and pinned both examples at `build`, the token for *nothing
  compiled, so no test ran*. Reproduced, and they are **two unrelated
  defects**, not the single cross-module one `AGENTS.md` claimed:
  - `function print/1 undefined`, in both, was **ours**: `main` wrote
    `print(…)` where the language reference only ever shows `@print(…)`. The
    bare call type-checks on every target and only commonJS lowers it (erlang
    emits an undefined local, beam an `unresolved_call`, wasm a trap), which
    is why the sibling `jhonstart-html` — already written with `@print` — was
    green on erlang all along. Fixed in both examples and in `docs.md`'s
    quickstart. It was never a test-mode problem: `botopink run --target
    erlang` failed the same way, and `botopink build --target erlang` exited 0
    only because a build transpiles without invoking `erlc`.
  - `function set/2 undefined`, in `jhonstart-counter` only, is **not ours**
    and is left standing: calling a record's function-typed field (`c.set(5)`
    on `State<T>`, gap G1) lowers correctly inside the declaring module and to
    a bare undefined local across a module boundary — which every consumer of
    `jhonstart/hooks` is. Handed to `00 · 02-erlang` as a self-contained
    jhonstart-free package under the new `repro/` directory, with the two
    collection sites in `codegen/erlang.zig` named. Working around it in the
    example would only have hidden it.

  So `jhonstart-todo` is now **3/3 on erlang** and `jhonstart-counter` still
  does not compile there. Neither `targets` array was widened — the ledger
  measures what a restriction hides, and lifting one is its own decision.

- **The element surface, step 5 — the shared files and the docs.** `docs.md`
  gains the constructor table, the three names that could not be the obvious
  one (`htmlTag`, `timeTag`, `main`) with their reasons and the `main`
  caveat, the consumer import a template resolution needs, and the two things
  the surface deliberately does not do (escape, and be void-aware in
  `renderToString`). `AGENTS.md`'s "the `Element` model has no **attribute**
  slot" line was stale — `attrs` landed — and is corrected in both the
  workspace and the `src/` index; `elements.bp` and `test/elements_test.bp`
  join the tree diagram and the module table. The whole front: 42 public
  functions (38 tag constructors, `el`, `voidEl`, `isVoidTag`,
  `isRawTextTag`), 15 inline `test {}` blocks plus 3 in the flat suite,
  **27/27 on commonJS and 27/27 on erlang** from a 9/9 baseline on each, and
  not one line changed in `element.bp`, `hooks.bp` or `html.bp`.
- **The element surface, step 4 — `modules/jhonstart/test/elements_test.bp`.**
  The `html """…"""` DSL resolves a lowercase tag to a bare `tag(...)` call in
  the **caller's** scope, so the only honest resolution test is one written
  from a consumer's position: the flat suite, next to `test/html_test.bp`,
  whose bare import is exactly that scope. Three blocks: a single-root
  template over an `elements.bp` tag renders identically to the equivalent
  constructor call; a template mixing an `element.bp` tag with an
  `elements.bp` tag resolves both; a `[class]={c}` bracket-prop reaches
  `attrs` on an `elements.bp` tag. 27/27 on commonJS and on erlang.
- **Known wart — `link/2` draws an erlc warning.** The erlang backend emits
  `-compile({no_auto_import,[...]})` only for a user function whose name AND
  arity are in the compiler's BIF catalog, and that catalog
  (`libs/std/src/erlang.bp`) lists `link/1` only. OTP 26 added
  `erlang:link/2`, so `elements:link/2` compiles with *ambiguous call of
  overridden auto-imported BIF link/2* on OTP 26+. It is a warning, not an
  error — the local definition wins and the erlang row is green — and the
  durable fix is one `link/2` entry in the compiler's catalog, which is not
  this repository.
- **The element surface, step 3 — the six void constructors**: `input`, `img`,
  `meta`, `link`, `br`, `hr`. They keep the uniform two-parameter shape and
  drop the children they are handed, through `voidEl`; the one-parameter
  `input(attrs:)` that would make children an arity error was rejected as a
  second convention, unreachable from the `html """…"""` DSL's call shape. A test
  asserts the drop. `link` is an Erlang auto-imported BIF at arity 1 and
  `link/2` here clears it — the erlang row proves it. `renderToString` is
  `element.bp`'s frozen in-repo test renderer and is **not** void-aware, so
  `renderToString(input([], attrs: []))` is `<input></input>`; the tests spell
  that wrong answer out as a literal, so that the day `element.bp` unfreezes
  the failing assertions point straight at the lines to change. The render
  that ships reads `isVoidTag`. 4 further inline `test {}` blocks, 24/24 on
  commonJS and on erlang.
- **The element surface, step 2 — the thirty-two non-void constructors.**
  Sectioning and flow (`a`, `nav`, `section`, `article`, `header`, `footer`,
  `main`, `aside`), headings and text-level (`h2`–`h6`, `label`, `timeTag`),
  forms (`form`, `button`, `select`, `option`, `textarea`), tables (`table`,
  `thead`, `tbody`, `tr`, `th`, `td`) and document (`htmlTag`, `head`, `body`,
  `title`, `script`, `style`). Each declaration is `element.bp`'s with the name
  and the tag string changed and nothing else — same parameter names, same
  order, same types, same declared default — and each body is one `el(...)`
  call. Three names could not be the obvious one: `htmlTag` (the package
  already exports the `html """…"""` template fn), `timeTag` (`time` is a std
  module a consumer may import in the same file) and, unchanged, `main` —
  which carries the caveat that a module declaring `fn main()` must not also
  import `main`, since a package import alias parses and is then ignored.
  Attribute order is the array order, and attribute values are verbatim; both
  are asserted. 7 further inline `test {}` blocks, 20/20 on commonJS and on
  erlang.
- **The element surface — `modules/jhonstart/src/elements.bp`** (1.0.10-beta
  front 94), step 1: the two builders every constructor in the file goes
  through, `el(tag, children, attrs)` and `voidEl(tag, attrs)` (which stores no
  children), plus the two predicates a void-aware renderer consults —
  `isVoidTag` (the HTML spec's fourteen: `area`, `base`, `br`, `col`, `embed`,
  `hr`, `img`, `input`, `link`, `meta`, `param`, `source`, `track`, `wbr`) and
  `isRawTextTag` (`script`, `style` — `title` and `textarea` are *escapable*
  raw text and are not in the set). `el` doubles as the public escape hatch for
  a tag the named surface does not carry. Attribute values are stored verbatim;
  escaping belongs to the renderer. `pub mod elements;` joins `src/root.bp` and
  `"elements.bp"` the member manifest's `files`. Nothing in `element.bp`,
  `hooks.bp` or `html.bp` was touched — all three are frozen for the milestone.
  4 inline `test {}` blocks, green on commonJS and on erlang (13/13 each, from
  a 9/9 baseline).
- **The umbrella is a workspace; the core lives in `modules/jhonstart/`**
  (1.0.10-beta front `02-packaging` step 2, decisions 75 + 76). The root
  `botopink.json` keeps only `name`, `version`, `description`,
  `targets ["commonJS", "erlang"]` and `"workspaces": ["modules/*", "examples/*"]` —
  `src`, `entry`, `files` and `dependencies` are located errors there — so it
  compiles nothing, ships nothing and answers no import; `botopink build/check/run/test`
  at the root refuses with the member list (`jhonstart, jhonstart-counter,
  jhonstart-html, jhonstart-todo`). `src/**` and `test/**` moved with `git mv`
  to `modules/jhonstart/`, whose manifest carries `name jhonstart`, `entry root.bp`
  and a `files` list that now begins with `root.bp`; `from "jhonstart"` resolves
  to that member. No source file was edited and nothing was reformatted.
  Measured either side of the move, against compiler `botopink-lang` feat
  `361d255d`: the core 9/9 on commonJS and 9/9 on erlang (3 element + 4 hooks +
  2 html), `jhonstart-counter` 4/4, `jhonstart-html` 7/7, `jhonstart-todo` 3/3,
  each building; `botopink test --target beam` is still "only the commonJS and
  erlang targets" (a runner skip).
- The three examples are **members**, depending on the core with
  `{ "jhonstart": { "workspace": true } }` in place of `{ "path": "../.." }`
  (which is now the *points at the workspace itself* refusal), each with `src`,
  `entry main.bp` and a one-line `description`. `jhonstart-counter` and
  `jhonstart-todo` restrict `targets` to `["commonJS"]`; their erlang cell is a
  pre-existing codegen red — an imported function called unqualified is emitted
  unqualified into the test escript (`main.erl:59: function print/1 undefined`,
  `main.erl:68: function set/2 undefined`), owned by `00 · 13-module-identity`
  (`codegen/crossModule.zig`). `jhonstart-html` declares no `targets` and
  inherits both, being 7/7 on each. `examples/jhonstart-app/` keeps **no**
  manifest and stays out: the `examples/*` glob skips a child without one,
  silently by design, and that sketch does not parse yet.
- `scripts/git-hooks/lib/runner-standalone.sh` is rakun's workspace-aware
  runner: when the root manifest carries `"workspaces"`, stage 2 runs
  `botopink test` inside **every** `modules/*/` member instead of over a root
  `src/` + `test/` that no longer exists. Stage 3 (the examples gate) is
  unchanged.
- **Known defect — the `.mjs` sidecar is resolved by name, not by the resolved
  dependency.** `shipMjsSidecars` (botopink-lang `modules/compiler-cli/src/cli/libs.zig`)
  asks `libDirByName` for the owning lib across the library roots rather than
  using the `{ "workspace": true }` dependency it already resolved, and a miss is
  **silent** — the build still exits 0 and only `node client.mjs` fails. Owner:
  front `00 · 10-cli-residuals`. Measured either side of the move by appending a
  marker line to the candidate `client_runtime.mjs` and grepping the built
  `out/` (every case exits 0): **before**, from a standalone checkout with no
  other `jhonstart` on the roots, `out/jhonstart/client_runtime.mjs` was **not**
  shipped — the root manifest was a package, so `rootsFrom` never added the
  directory itself and nothing on the roots was named `jhonstart`. **After**, it
  **is** shipped from `modules/jhonstart/src/` — the root manifest is a
  workspace, so the directory becomes a root and contributes its members — both
  standalone and at `repository/jhonstart/` (the shape this lands as on `feat`,
  where `addUnique` de-dups the same directory reached through two roots). The
  one case that still misses is a `.tasks/` worktree beside a main checkout that
  also declares the name `jhonstart`: two directories, one name →
  `resolveDuplicateNames` marks both *declared by two libraries* and
  `libDirByName` skips an entry carrying a problem. So the move **fixed** the
  sidecar, and the old `BOTOPINK_LIB_ROOTS` workaround — a real directory
  literally named `jhonstart` with a symlinked `src/` — is obsolete: the lookup
  is by manifest name since the front's step 1.
- `botopink format --check` is unchanged by the move and still red on the same
  files at their new paths: 6 would be reformatted
  (`modules/jhonstart/src/html.bp`, `modules/jhonstart/test/html_test.bp`,
  `examples/*/src/main.bp`, `examples/jhonstart-app/main.bp`) and 3 do not parse
  (`examples/jhonstart-app/app/{layout,page}.bp`, `app/posts/[id]/page.bp`). A
  packaging commit reformats nothing.
- **`use` activation after decision 88 (botopink-lang 1.0.10-beta front 19):**
  `use f(x)` lowers to `f(x)` on every backend and a body that activates a hook
  carries `#[@context]`. Every component and custom hook is annotated
  (`hooks.bp`'s `Counter`/`counter`, the counter and todo examples); hooks are
  nouns — `useCounter` → `counter`, `useRouter` → `router` (and its host
  symbol), `useToggle` → `toggle` — called as `use counter(…)`, bound under
  another name. `hooks.bp`'s header no longer claims the prefix lowers to
  React's `useState`. `router.d.bp` imports `Element`.
- **Client runtime.** `src/client_runtime.mjs` exports the five nouns with hook
  semantics (plus `render(component, commit)`) over jhonstart's own re-render
  loop; the client build resolves `jhonstart/hooks` to it. `src/client_runtime.bp`
  (`mod`, not consumer surface) carries the `clientRender` cell whose
  `./client_runtime.mjs` require makes `botopink build` ship the sidecar.
  `examples/jhonstart-counter/client.mjs` runs the built `Counter` under it on
  node and prints the re-renders after `set`.
- The three examples depend on jhonstart by `{ "path": "../.." }` (decision
  76), the checkout they live in — a `git` dependency resolved by name to
  `repository/jhonstart`, the main checkout, from inside a worktree.
  *(Superseded above: `../..` is the umbrella, so the form is now
  `{ "workspace": true }`.)*

- **1.0.3 surface** (botopink-lang front 12): `Element` and `State<T>` are
  `type Name(fields)`; `Router` / `Request` are `behavior`s whose bodiless members
  end with `;`; the hook shapes are labeled tuple types — `effect` yields `#()`,
  `ref` `#(current: T)`, `reducer` `#(state: S, dispatch: fn(action: A))`; the
  `html` lexer's tokens are tuples typed by `tokens`' written element type. Two
  compiler gaps are worked around with positional access: labels of a generic
  labeled return are lost when `T` is instantiated (the hooks test reads `r.0`),
  and label access on a lambda parameter is not rewritten in a template body
  (`t.0` … `t.6`). `botopink format` is not applied: it currently emits code that
  does not compile here.

- The examples gate no longer aborts silently on a `scripts/known-broken-examples.txt`
  holding only comments or blank lines: the runner reads the list with `awk`, whose
  "no entry" is not a failure under `set -euo pipefail`.

- `examples/jhonstart-counter`, `jhonstart-html` and `jhonstart-todo` build again:
  their element builder calls pass `attrs` explicitly — the `attrs = []`
  default is not applied by the compiler yet — and they leave
  `scripts/known-broken-examples.txt`.

- **MIT license.** `LICENSE` (`Copyright (c) 2026 Eric Fillipe and botopink
  contributors`) backs the README's License section, which now points at it.

- The gate builds the examples: after `botopink test`, the pre-commit hook
  and CI run `botopink build` in every `examples/*/` with a `botopink.json`;
  `scripts/known-broken-examples.txt` lists the ones allowed to fail, and a
  listed example that builds fails the gate.
- `examples/jonhstar` removed: a misspelled early expr-templates showcase with
  its own stale copy of the `html` template (`src/jhonstart.bp`), no
  dependency on jhonstart, not referenced by the README, and failing to
  build (`unbound variable 'html'`); `jhonstart-html` covers the same ground.
- The pre-commit hook is self-contained: the dead delegation to a meta
  workspace runner is gone, and `AGENTS.md` documents the install
  (`git config core.hooksPath scripts/git-hooks`) instead of a
  `scripts/install-hooks.sh` that exists in no repository.
- Promoted from workspace subdir to standalone repository under
  `botopink/jhonstart`. Tracked from `botopink/projects` as a git submodule on
  the `feat` branch.
- `Router` and `Request` read their fields through zero-argument methods
  (`router.pathname()`, `req.params()`, `req.query()`): `get` is no longer a
  keyword, so the `get name(self: Self)` accessors did not parse. Their host
  hooks are `pub declare fn`, so both declaration files parse whole.

## 0.0.1 — v0.beta.8

- `html """…"""` DSL implemented in real `.bp` (stack-based parser, dual lowering
  via `@ExprCustom<Element>`).
- Component model: function returning `Element`, real builder chain.
- Hook family in real `.bp`: `useState`, `useEffect`, `useMemo`, `useRef`,
  `useReducer`.
- Server components: `*fn … -> @Future<Element>` skeleton (the `*fn`
  carrier was migrated to the `#[@future]` annotation in v0.beta.12 and
  the legacy prefix removed in v0.beta.19).
- Synchronous SSR (`renderToString`).

## 0.0.0 — v0.beta.5

- Initial spec and framework scaffold (the port).
