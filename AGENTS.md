# rakun

> Path: `repository/rakun/`
> Parent (workspace): [`../AGENTS.md`](../AGENTS.md) · Sibling (core): [`../botopink-lang/AGENTS.md`](../botopink-lang/AGENTS.md)
> Docs: [`./docs.md`](docs.md) · Spec: [`../../tasks/v0.beta.11/specs/rakun.md`](../../tasks/v0.beta.11/specs/rakun.md)

A **Spring-style application framework** for botopink — an IoC container with
constructor dependency injection plus a declarative web layer (`#[restController]`
+ route annotations). **Opt-in, never auto-loaded:** it enters a module's scope
only via `from "rakun"`. **The compiler core knows nothing about rakun** — every
behaviour is plain botopink + a host runtime, on the generic annotation-processor
mechanism (`@Decl` reflection, comptime decorator bodies, `@emit`).

How the wiring works: each component decorator (`decorators.bp`) is a comptime fn
over the annotated `type` (`DeclKind.Type` with no `variants` — an enum-shaped `type` is rejected). It `@emit`s, at the application site, (1) a scan
self-registration and (2) a SINGLETON factory `__rkMake_<Type>()` that constructs
the value once (`rkSingleton`) and caches it, injecting each field by its own
factory — except a `#[value("key")]` field, filled from config (`rkProp`/
`rkPropInt`) and kept OFF the DI graph. A controller additionally `@emit`s one
route registration per mapped method (reading `decl.methods` + the `#[route]`
prefix); a `#[configuration]` `@emit`s a `__rkMake_<ReturnType>()` per `#[bean]`
method. botopink has no top-level mutable state, so the registries those calls
feed — the scan list, the singleton cache, the cycle guard, the config props, the
router table — live in the BEAM host module `sidecars/rakun_runtime.erl`, reached
through the `#[@External.Erlang]` declarations in `runtime.bp`. rakun is
erlang-only (decision 113). The emitted code references those runtime fns by
name, so a module declaring components also imports them (`import {service,
rkScan, rkSingleton, rkEnter, rkDone, rkRegisterRoute, …} from "rakun"`). The HTTP
value types + the `Request` behavior are real emitted code (`http.bp`);
`Rakun.run` (`bootstrap.bp`) starts rakun's own `gen_tcp` transport
(`rkServe` → `serve/2` in `rakun_runtime.erl`).

## Tree

The repository is a **workspace** (decision 75 of 1.0.10-beta): the root `botopink.json` declares
members and is never a package — no `src`, `files`, `entry` or `dependencies`; `botopink build/test`
there is the located refusal `botopink.json is a workspace, not a package — run this command inside
one of its members: …`. Every `modules/*/` and `examples/*/` holding a `botopink.json` is a member,
named by its own manifest. The **core is the member `modules/rakun/`**; `from "rakun"` resolves to it.

```text
rakun/
├── AGENTS.md          ← you are here
├── docs.md            ← what this lib provides + Spring mapping + loading notes
├── botopink.json      ← WORKSPACE: name rakun · version · targets [erlang] (decision 117
│                        rule 9 — every member declares [erlang] too) · workspaces
│                        ["modules/*", "examples/*"]. Nothing importable from it.
├── modules/
│   ├── README.md      ← the member table (14 today, 13 planned with their fronts), the
│   │                    module ↔ Spring starter map, how to add a member
│   ├── rakun/         ← THE CORE — what `from "rakun"` gives a consumer
│   │   ├── botopink.json  name rakun · entry root.bp · target erlang · targets [erlang]
│   │   │                    (front 04 Step 10, decision 113) · files: root · http ·
│   │   │                    runtime · decorators · bootstrap · rakun.d · no dependencies.
│   │   │                    The `.erl` sidecar is NOT a `files` entry: `shipErlSidecars`
│   │   │                    finds it under the package's `src/sidecars/`
│   │   ├── src/
│   │   │   ├── root.bp        ← module-tree root: `pub mod decorators; http; runtime; bootstrap;`
│   │   │   ├── http.bp        ← concrete, emitted: `HttpMethod` enum-shaped type · `Response` type
│   │   │   │                    (builders) · `App` config · `Request` behavior
│   │   │   ├── runtime.bp     ← the host cells, each one `@External.Erlang` form
│   │   │   │                    (`rkScan`/`rkSingleton`/`rkEnter`/`rkDone`/`rkProp`/
│   │   │   │                    `rkRegisterRoute`/`rkDispatch`/`rkDispatchHttp`/`rkServe`/…)
│   │   │   ├── sidecars/
│   │   │   │   └── rakun_runtime.erl ← THE ERLANG HOST MODULE (§ The erlang host module):
│   │   │   │                    the `application` + supervision tree + ETS tables behind
│   │   │   │                    every `@External.Erlang` cell. Shipped by
│   │   │   │                    `shipErlSidecars`; the atom may not be `runtime`
│   │   │   ├── ssl_bundle.bp  ← THE SSL BUNDLE REGISTRY (§ TLS and the SSL bundle
│   │   │   │                    registry): the property grammar, the refusals,
│   │   │   │                    the two option-list encodings, reload, and the
│   │   │   │                    `ssl` health and info contributions
│   │   │   ├── sidecars/rakun_ssl.erl ← the same on the BEAM, plus the one
│   │   │   │                    genuinely erlang-only piece: the blob →
│   │   │   │                    `ssl:listen/2` option list decoder front 04's
│   │   │   │                    acceptor takes
│   │   │   ├── decorators.bp  ← the markers AS comptime decorator fns: placement rules +
│   │   │   │                    the DI/router/scope/bean wiring they `@emit`
│   │   │   ├── request_context.bp ← THE REQUEST CONTEXT (§ The request context):
│   │   │   │                    the frame, its epoch, the five phases and the
│   │   │   │                    refusal texts. Every accessor raises outside a
│   │   │   │                    request and there is no flag that changes it
│   │   │   ├── request_memo.bp ← the `React.cache` analogue over the frame's
│   │   │   │                    table: `memoize` · `preload` · `memoKey`
│   │   │   ├── sidecars/rakun_request_context.erl ← the frame on the BEAM: ONE
│   │   │   │                    process-dictionary key plus an ETS area that
│   │   │   │                    outlives it, for work that runs after the response
│   │   │   ├── context.bp     ← THE CONTAINER'S DOORS (§ The container's doors):
│   │   │   │                    the bean registry, `Context`, `#[managed]`,
│   │   │   │                    `#[provides]`, `#[qualifier]`/`#[primary]`/
│   │   │   │                    `#[lazy]`/`#[scope]`/`#[imports]`, the eager pass
│   │   │   │                    and `bootSequence()`
│   │   │   ├── events.bp      ← one `Event(name, source, payload,
│   │   │   │                    timestampMillis)` record, the listener table and
│   │   │   │                    `#[eventListener]`; the eight boot event NAMES
│   │   │   ├── lifecycle.bp   ← `#[postConstruct]`/`#[preDestroy]` (placement
│   │   │   │                    only), the two passes, `#[exitCode]`,
│   │   │   │                    `shutdown()` and the process status
│   │   │   ├── sidecars/rakun_context.erl ← the same four on the BEAM, in ETS
│   │   │   │                    behind a dedicated owner process
│   │   │   ├── autoconfig_registry.bp ← THE AUTO-CONFIGURATION SEAM (§ The
│   │   │   │                    auto-configuration pass): the host cells behind the
│   │   │   │                    registration table, plus the `botopink.json`
│   │   │   │                    dependency read `#[conditionalOnModule]` asks
│   │   │   ├── sidecars/rakun_autoconfig.erl ← the same table on the BEAM, in ETS
│   │   │   │                    behind a dedicated owner process
│   │   │   ├── conditions.bp  ← the five condition markers, the `M|P|B|X|F` wire
│   │   │   │                    format and the ONE evaluator that answers a record
│   │   │   ├── autoconfig.bp  ← `#[autoConfiguration]`, the topological sort, the
│   │   │   │                    apply pass, the gate and the four application calls
│   │   │   ├── condition_report.bp ← the three-block render: applied, not applied,
│   │   │   │                    excluded, each failure naming the value observed
│   │   │   ├── bootstrap.bp   ← `Rakun` (concrete type): `Rakun.run(app)` starts `rkServe`
│   │   │   └── rakun.d.bp     ← the declaration module. EMPTY since front 06: it
│   │   │                        carried a declaration-only `behavior Context`,
│   │   │                        which the concrete `context.bp` one replaced
│   │   └── test/
│   │       ├── di_test.bp     ← placement + component scan
│   │       ├── router_test.bp ← DI chain + router dispatch (200 / 404) end to end
│   │       ├── scopes_test.bp ← singleton scope (diamond) · `#[value]` · `#[bean]` (F2-scopes)
│   │       ├── server_test.bp ← the live HTTP dispatch pipeline (`rkDispatchHttp`): path
│   │       │                     param · query/header/body · 200/404 (F5)
│   │       ├── request_context_test.bp ← the frame lifecycle and the epoch
│   │       │                     discipline, the keep-alive case FIRST
│   │       ├── request_memo_test.bp ← hit/miss counts, per-request lifetime,
│   │       │                     preload single-flight, non-poisoning
│   │       ├── overlapping_routes_test.bp ← two controllers sharing a path prefix both
│   │       │                     register; dispatch matches the FULL path; a leaf (no-dep)
│   │       │                     #[service] resolves through the DI chain
│   │       ├── context_test.bp ← the bean registry, `Context`, the parent/child
│   │       │                     chain, qualifiers, scopes, lifecycle, the eager
│   │       │                     pass and shutdown. The SAME assertions on both
│   │       │                     rows
│   │       ├── events_test.bp ← listener dispatch, ordering, the boot sequence
│   │       │                     asserted as a WHOLE, and the failure path
│   │       ├── conditions_test.bp ← front 72's COMPTIME half: the exact blob each
│   │       │                     annotation set produces, read straight back out of
│   │       │                     the host table, and the evaluator letter by letter
│   │       ├── autoconfig_test.bp ← front 72's RUN-TIME half: the sort, the ordered
│   │       │                     `#[conditionalOnMissingBean]` answer, the gate, both
│   │       │                     exclusion channels, idempotence and the report
│   │       └── erlang_runtime_test.bp ← the host cells named DIRECTLY (no decorator):
│   │                             scan order · singleton/build count · the parseInt rule ·
│   │                             route order · the `Response` round-trip shape. The same
│   │                             assertions on BOTH rows — green on commonJS and on erlang
│   │                    (front 14's `rakun-validation` member moved to the bundled library
│   │                    `validation`, decision 116 rule 5; its `boot.bp` is
│   │                    `modules/rakun/src/config_check.bp` — § Validation)
│   ├── rakun-app/     ← THE SERVER HALF OF THE `app/` ROUTER (front 95 relocated fronts 22 and
│   │   │                23 out of the core — `specs/1.0.10-beta/03-rakun/modules.md` § The cut):
│   │   │                files [root.bp, file_router.bp, ssr.bp], targets [erlang],
│   │   │                depends on `rakun` by `{ "workspace": true }`; imports the
│   │   │                core `from "rakun"` (the request context `from "rakun/request_context"`,
│   │   │                because std's `encoding` also declares `percentDecode`)
│   │   ├── src/
│   │   │   ├── root.bp        ← `pub mod file_router; pub mod ssr;`
│   │   │   ├── file_router.bp ← the FILE-CONVENTION route table (§ The file-convention
│   │   │   │                    route table): the registry, the `app/` scan and the four
│   │   │   │                    markers, over the bundled `routing` library's segment
│   │   │   │                    grammar, `kind|pattern|slot|verb` wire and matcher. `decorators.bp` is frozen, so the markers
│   │   │   │                    live here, as `#[configurationProperties]` does
│   │   │   ├── sidecars/rakun_file_router.erl ← the same registry on the BEAM, in
│   │   │   │                    ETS behind a dedicated owner process
│   │   │   ├── ssr.bp         ← THE SSR PIPELINE (§ The SSR pipeline): the escaping
│   │   │   │                    walker, the composition order, `RenderHooks`, the
│   │   │   │                    payload, the document and the chunk protocol.
│   │   │   │                    Generic in `El` throughout — rakun declares no
│   │   │   │                    dependency on jhonstart and gains none here
│   │   │   └── sidecars/rakun_ssr.erl ← the same cells on the BEAM, in the serving
│   │   │                        process's dictionary; `all/1` spawns one monitored
│   │   │                        child per thunk, because `@Task` is eager there
│   │   └── test/            (+ `test/fixtures/{routing,conflict-both,conflict-roots,middleware}`)
│   │       ├── file_router_test.bp ← the registry cells, the host table against
│   │       │                     the matcher, the page context (the grammar, wire and
│   │       │                     matcher tests moved to `libs/routing/test/`). The SAME
│   │       │                     assertions on both rows
│   │       ├── file_router_markers_test.bp ← the four markers at module level and
│   │       │                     the accessors they emit; no `rkAppReset()`, because
│   │       │                     a module-load registration cannot be snapshotted in
│   │       │                     its own module
│   │       ├── file_router_scan_test.bp ← the scan over real fixture trees under
│   │       │                     `test/fixtures/{routing,conflict-both,conflict-roots,
│   │       │                     middleware}`: the conflicts, the `_` skip, `app` vs
│   │       │                     `src/app`, the root `middleware.bp`
│   │       └── ssr_test.bp    ← the SSR pipeline: the rendered page, the escaping
│   │                             walker, the composition order, the payload round
│   │                             trip, the chunk protocol and the two entry points.
│   │                             Every cell runs on BOTH rows
│   ├── rakun-web/     ← THE FILTER CHAIN (§ The filter chain): the one ordered chain
│   │   │                between the socket and the route handler, its two entry
│   │   │                points, CORS and RFC 9457 problem details. target/targets
│   │   │                erlang; depends on `rakun` by `{ "workspace": true }`
│   │   ├── src/
│   │   │   ├── root.bp        ← `pub mod filter; error; middleware; cors; convention;`
│   │   │   ├── filter.bp      ← the chain: `WebRequest` · `Chain` · `Filter` ·
│   │   │   │                    `chainNext`/`runChain` · the order band · the
│   │   │   │                    status-0 sentinel · `withHeader`/`withHeaders` ·
│   │   │   │                    the `Set-Cookie` list · the route read
│   │   │   ├── middleware.bp  ← `Next` (pass · redirect · permanentRedirect ·
│   │   │   │                    rewrite), the matcher (`validateMatcher` /
│   │   │   │                    `matcherAdmits` over the bundled `routing` `pattern`
│   │   │   │                    grammar; `""` runs everywhere) and the one-middleware rule
│   │   │   ├── cors.bp        ← `CorsPolicy`, the three restrictive defaults, the
│   │   │   │                    preflight, the per-controller mappings
│   │   │   ├── error.bp       ← `ProblemDetail`, `raiseProblem`, the advice
│   │   │   │                    registry and the error entry
│   │   │   ├── convention.bp  ← the five markers (`#[filter]` · `#[order]` ·
│   │   │   │                    `#[middleware]`/`#[matcher]` · `#[crossOrigin]` ·
│   │   │   │                    `#[controllerAdvice]`/`#[exceptionHandler]`), the
│   │   │   │                    request-id built-in and `bootWeb()`
│   │   │   └── sidecars/rakun_chain.erl ← the same on the BEAM (ETS behind an
│   │   │                        owner process + the process dictionary), plus
│   │   │                        `run/6`, the seam `dispatch_http/5` calls
│   │   └── test/
│   │       ├── middleware_test.bp ← ordering as ONE string · short-circuit ·
│   │       │                     `Next` · the matcher · `withHeader`
│   │       ├── cors_test.bp   ← the deny-all default · the echoed origin · the
│   │       │                     preflight · the two boot refusals
│   │       ├── error_test.bp  ← the RFC 9457 shape · the advice · the digest
│   │       │                     that reaches the body and the reason that does not
│   │       └── decorators_test.bp ← the five markers and what they emit; NOTHING
│   │                             here resets a table
│   ├── rakun-test/    ← the `<lib>-test` member (front 95, `specs/1.0.10-beta/02-packaging/README.md`
│   │                    § 5): files [root.bp], an EMPTY `pub` surface and one inline `test` proving
│   │                    the core resolves from it; front 19 fills it (request doubles, MockMvc,
│   │                    the `assert<Subject>(loc, …)` helpers). Re-exports nothing from std
│   └── rakun-<area>/  ← the ten remaining scaffolds (actuator · cache · client ·
│                        data · hateoas · logging · messaging · scheduling · security ·
│                        session): `botopink.json` (files [root.bp] · targets per
│                        `specs/1.0.10-beta/03-rakun/modules.md` § Targets · dependencies
│                        { "rakun": { "workspace": true } }) + a two-comment `src/root.bp`;
│                        contents land per front
├── examples/
│   ├── rakun/         ← member `rakun-example` (an application: entry main.bp, target erlang,
│   │                    depends on `rakun` via { "workspace": true }); the sixty-second app
│   ├── rakun-container/ ← member `rakun-container-example`: front 06's surface reached
│   │                    through `from "rakun"`, which is the CONSUMER proof that
│   │                    `Context` resolves to one declaration and not two
│   └── rakun-ssr/     ← member `rakun-ssr-example`: front 23's surface reached
│                        through `from "rakun"` — the element adapter, a layout
│                        and a page, one render inside a request scope, and the
│                        escaping assertion. `botopink run` prints the document
└── scripts/git-hooks/ ← the pre-commit gate (§ Local gate): `botopink test` per module member,
                         `botopink build` per example
```

## Module tree (`root.bp`)

`modules/rakun/src/root.bp` is the explicit module-tree root — the core builds from it, not
a deprecated blind `src/` scan. It declares the four compiled modules
`pub mod decorators; pub mod http; pub mod runtime; pub mod bootstrap;` (all
public surface, reached via `from "rakun"`; the `@emit`ted wiring imports the
runtime fns by name). The declaration module `rakun.d.bp` (the future `Context`
behavior) is **not** in the tree: it is wired through the core's `botopink.json` `files`
(`modules/rakun/botopink.json`), which also lists `root.bp` first — decision 75's rule that a
library member lists every module a consumer may import, or it `ships nothing`.
`.d.bp` modules are not resolved by `mod` paths (the resolver follows only
`<name>.bp` / `<name>/mod.bp`), mirroring how `libs/std` keeps its ambient `.d.bp`
out of `root.bp`. Since front 06 that declaration module declares NOTHING — its
`behavior Context` was replaced by the concrete `pub type Context` in
`context.bp`, and leaving the stub would have put two `Context` declarations into
every consumer's namespace. It keeps its place in `files`, as the library's
declaration module for the next boundary interface that needs one.

Front 06 appended `pub mod events; pub mod lifecycle; pub mod context;` to the
tree and the matching entries to `files`, in that order and reordering nothing:
`context` imports both siblings (the boot sequence publishes the eight events and
runs the post pass), and the `files` ORDER is a dependency order a consumer's
build reads literally. Front 72 appended `pub mod autoconfig_registry; pub mod conditions; pub mod
autoconfig; pub mod condition_report;` and the matching `files` entries, in that
order and reordering nothing: `conditions` imports `autoconfig_registry`,
`autoconfig` imports both, `condition_report` imports all three — and
`conditions` also imports `context` (front 06's `rkBeanNames` is half the answer
to `#[conditionalOnBean]`), which is why the four sit after it rather than beside
`runtime`.

Front 22's `file_router` and front 23's `ssr` were in this tree until front 95
relocated them to the `rakun-app` member (`03-rakun/modules.md` § The cut): nothing
in the core imported either, so the two `pub mod` lines and the two `files` entries
left and nothing else in the core moved.

Front 74 appended `pub mod ssl_bundle;` and the matching `files` entry, last and
reordering nothing: it imports `runtime` (the property table) and `config` (the
typed readers and `rkValue`), and nothing inside rakun imports it — fronts 04,
08, 09, 13, 15, 76, 79, 85 and 90 do, from outside, and
`modules/rakun-web/src/tls.bp` is the first of them. Its host file
(`src/sidecars/rakun_ssl.erl`) is NOT a `files` entry, for the reason
`rakun_runtime.erl` is not.

rakun declares **no dependencies**: the HTTP transport
`Rakun.run` starts is `serve/2` in its own `rakun_runtime.erl` (bound as `rkServe`), so a
consumer declares only `rakun`. (It used to name a `server` library that exists in
no repository — `botopink check` failed with `LibNotFound` before reading rakun's
source.)

**rakun is erlang-only (decision 113; decision 117 rule 9; front 04 Step 10).** The
workspace root and every member — the core, `rakun-app`, `rakun-web`, `rakun-test`, the
ten scaffolds and the three examples — declare `"targets": ["erlang"]`, and each package
`"target": "erlang"` (the build target the CLI reads, `config.zig`; `targets` is the
per-member whitelist `botopink-lib-test` reads). `botopink test` / `build` / `run` default
to erlang here. The node host halves (`runtime.mjs`, `context.mjs`, `request_context.mjs`,
`autoconfig.mjs`, `ssl_bundle.mjs`, `rakun-app`'s `file_router.mjs` / `ssr.mjs`, `rakun-web`'s
`chain.mjs`) are deleted and no `#[@External.Node]` form remains in any member: every host
cell is one `@External.Erlang` form. What both a browser and the server run is not a rakun
member — the matcher and the navigation vocabulary are the bundled `routing`, the action
protocol `actions`, validation `validation` (decisions 115, 116). The sections below that
reason about "both rows", a "node twin" or `runtime.mjs:N` record why each piece was
shaped as it is while the core still ran on commonJS; the `runtime.mjs:N` citations name
the node code `rakun_runtime.erl` was ported from, term for term.

**Measured 2026-09-26 (compiler `f011850c`), after the move:** `modules/rakun` **310 / 0**,
`modules/rakun-app` **59 / 0**, `modules/rakun-web` **104 / 0**, `modules/rakun-test`
**1 / 0** — erlang, the only row. The two erlang reds every front since 04 carried
(`server_test.bp:74,80`, `{badkey,param}` / `{badfun,…}`) were front 04's own `request/6`:
the erlang backend dispatches a method a `behavior` declares without a body through the
value — `(maps:get(param, Req))(Req, N)` — and the map carried data under `query` / `body`
and no funs. It now carries `param` / `query` / `header` / `body` as funs taking the
receiver first, and the data under `params` / `query_map` / `headers` / `body_bin`.

**What the move costs, and where it is owed.** (1) `botopink run` / `build` on erlang
neither ships nor loads a sidecar (`shipErlSidecars` is called only from `test_cmd.zig`;
`__bp_load_siblings/0` is emitted only under the test flag), so the three examples BUILD
on erlang but a built program dies at the first host call (`undef rakun_runtime:serve/2`)
— the compiler's `00 · 10-cli-residuals` gap, front 04 § Blocked. `examples/rakun` served
HTTP on node until the move; it serves again on the BEAM when that gap closes. (2) The
compiler repository's `scripts/restricted-targets.txt` pins the old matrix; its rakun
rows are the compiler repository's to edit (the erlang rows of `rakun`, `rakun-example`,
`rakun-container-example`, `rakun-ssr-example` leave; each member's commonJS row enters
as a `build` restriction — `test-libs` names every line). rakun has no line in
`known-red-libs.txt`.

## The erlang host module

`modules/rakun/src/sidecars/rakun_runtime.erl` is rakun's host runtime, ported
term for term from the deleted `runtime.mjs`. Every host cell in `runtime.bp`
carries one form, `@External.Erlang("rakun_runtime", "<snake_case>")`;
`test/erlang_runtime_test.bp` names the cells directly.

**The module atom may not be `runtime`.** `shipErlSidecars`
(`compiler-cli/src/cli/libs.zig`) reads the `atom:fun(` qualifiers out of the
emitted erlang, skips any atom matching a module *this build emitted*, and copies
the rest from `<lib>/src/sidecars/<atom>.erl`. rakun emits `rakun/runtime`, whose
basename is `runtime`, so a sidecar called `runtime.erl` is skipped — and the skip
is SILENT: the build exits 0 and the program dies at run time with
`undefined function runtime:scan/1`. Every rakun sidecar is therefore
`src/sidecars/rakun_<name>.erl`, and a change here is verified by looking inside
the output directory (`.botopinkbuild/test-out/rakun_runtime.erl`), never by
trusting the exit code. The same rule names the cowboy adapter seam
`src/sidecars/rakun_cowboy.erl` if it is ever built.

**One module, three OTP roles.** `shipErlSidecars` copies a sidecar only when its
atom appears in emitted botopink output, so `rakun_sup`, `rakun_registry` and
`rakun_conn_sup` — which botopink code never names — could not be separate files:
they would never be shipped. They are registered *names*, not modules. `?MODULE`
is the callback module for the application, the supervisors and the table-owning
`gen_server`, and `init/1` dispatches on its argument. Only
`-behaviour(application)` is declared: adding the other two makes `erlc` emit
`conflicting behaviours ... init/1`, which `-Werror` turns into a failure.

| rakun concern | OTP piece | Why |
|---|---|---|
| The runtime as a startable unit | `application` (`rakun`) | `application:start/1` is the only thing that gives the ETS tables an owner that outlives a request. There is no `rakun.app` file — a sidecar is compiled by `compile:file/2` at run time — so the spec is loaded from a term by `ensure_started/0` |
| Keeping the tables alive | `supervisor` (`rakun_sup`, `one_for_one`) | A crash must not take the singleton cache with it |
| Owning the ETS tables | `gen_server` (`rakun_registry`) | ETS tables die with their owning process; this is the owner that never exits, and a restart recreates them EMPTY rather than leaving dangling ones |
| Scan list · singleton cache · build counts · property map · route table · failure table | ETS (`named_table, public, read_concurrency`) | The node `Map`/array equivalents; a request process reads without a message round trip |
| Cycle guard, per-request reply headers | process dictionary | Per-process on the BEAM *is* per-construction and per-request, which is the scope node gets by accident from being single-threaded |
| Accepting sockets | `gen_tcp` with `{packet, http_bin}` | OTP decodes the request line and the headers itself, so rakun writes no HTTP parser and depends on nothing outside `kernel` |
| One process per connection | `supervisor` (`rakun_conn_sup`, `simple_one_for_one`, temporary children) | A handler that throws kills its own connection process and nothing else — the BEAM answer to `runtime.mjs`'s try/catch |
| Boot-time keep-alive | `receive after infinity` | `main/1` returning halts the node, so a bound — or headless — app must wait |

`ensure_started/0` is the first line of every cell and costs one `ets:whereis/1`
on the warm path.

### Rules the two rows share

- `prop/1` answers `""` for an absent key and `prop_int/1` answers `0` for an
  absent or unparsable one. `prop_int/1` is `parseInt(v, 10)` — a LEADING integer
  wins, so `"12abc"` is `12` on both rows. `#[value("key")]` must not mean two
  things on two targets.
- `scanned_names/0` answers in declaration order (an `ordered_set` on a monotonic
  sequence), not sorted and not a set.
- `singleton/2` inserts with `ets:insert_new/2`: two request processes that miss
  the cache at the same instant keep ONE instance, the loser discarding its value.
  `build_count/1` is then 1 or 2 — never a function of the number of readers.
- The router walks in registration order and takes the first route whose verb,
  segment count and every segment match (`:name` binding a path parameter).
  Registration order decides between two routes that both match, on both rows.
- `dispatch_http/5` carries THE ONE HOOK later fronts hang off:
  `rakun_chain:run/6` when `rakun_web` is in the build, the handler directly when
  it is not. `Rakun.run` is frozen and hardcodes this dispatcher, so front 07's
  filter chain, CORS, compression, error handling and API versioning all enter
  here — and front 10's security filter and front 11's request metrics enter
  through front 07's chain, not through a second hook.

### The server half — cells with no node twin

(Written while the core still ran on commonJS; since the erlang-only move an
erlang-only cell CAN be asserted from a `.bp` test.) `runtime.mjs` was frozen for the milestone, so four pieces of the erlang host
module have no `@External.Node` counterpart and therefore no `rk*` cell:
`set_reply_header/2`, `reply_headers_json/0`, `boot/1` and `add_failure/3`.
They are reached from erlang (by the acceptor, and by later fronts' sidecars),
not from `.bp`. **A cell that is erlang-only cannot be asserted from a `.bp`
test**: `botopink test` compiles every `test/*.bp` on BOTH rows with no
per-target gate, and calling a cell with no node form is a located diagnostic
that reddens the commonJS row. So these four are covered by the erlang-side
round-trip, not by the `.bp` suite — which is the honest place for them until
either `runtime.mjs` unfreezes or a test file can declare its target.

- **Reply headers.** `Response` is `(status, body)` and `http.bp` is frozen, so
  there is no field for a header. A request is a process, so the accumulator is
  process-local: a request that sets none pays nothing, two requests never see
  each other's, and the connection process clears it between keep-alive
  requests. A second write to the same name replaces the first
  (case-insensitively) and `reply_headers_json/0` keeps INSERTION order.
- **Boot options.** `App(port, basePath)` is frozen and cannot grow a field, so
  Spring's `SpringApplication` builder options are configuration keys — read
  through `prop/1`, so front 05 feeds them automatically once it lands — plus
  `boot/1`, which writes the SAME properties from a JSON string for a program
  that would rather set them in code than in a file. One resolution path.

| Key | Default | Effect |
|---|---|---|
| `rakun.main.banner-mode` | `console` | `banner.txt` from the working directory with `${application.version}`, `${rakun.version}` and `${otp.version}` substituted; a one-line default with no file. `off` prints nothing — and a test run prints nothing whatever it says |
| `rakun.main.headless` | (unset) | `true` starts no listener; the route table is still built |
| `rakun.main.keep-alive` | (unset = wait) | `false` makes `serve/2` return the bound port instead of blocking — the CI smoke shape, and the only way to observe the port from a caller |
| `rakun.main.pid-file` | (unset) | `os:getpid()` is written at boot and the file removed on a clean return |
| `rakun.main.port-file` | (unset) | the BOUND port, so `port: 0` writes the ephemeral one |
| `rakun.server.backlog` | `128` | `gen_tcp:listen/2`'s backlog |
| `rakun.server.idle-timeout` | `60000` | an idle keep-alive connection is closed after this many ms |
| `rakun.server.max-connections` | `16384` | over the limit the acceptor answers 503 and closes without spawning |
| `rakun.server.transport` | (unset = `gen_tcp`) | a named transport delegates to `rakun_<name>:serve/2`; a name whose module will not load is a startup FAILURE naming it, never a silent fall back |
| `rakun.server.bound-port` | — | written by the listener, read by `serve/2`; not a tuning key |

- **Why `gen_tcp` and not cowboy.** A sidecar is compiled by `compile:file/2` at
  run time with no rebar, no `.app` file and no code path beyond the output
  directory, so `cowboy:start_clear/3` compiles fine and then dies with
  `undefined function` on every machine that has not separately installed
  cowboy — and rakun's test row would depend on an OTP application the gate does
  not install. `gen_tcp` is in `kernel`. Cowboy stays available as an ADAPTER
  through `rakun.server.transport`, at `src/sidecars/rakun_cowboy.erl`.
- **Startup failure diagnostics.** A table keyed by the error term, consulted
  before the node halts: three blocks (the error, a description, an action) plus
  the one thing a table row cannot carry — the port that was taken, the
  transport value and the module it looked for, the construction stack
  innermost last. An unmatched error prints the raw term and SAYS no diagnosis
  is available; it does not guess. The table is data, extended by later fronts
  through `add_failure/3` without editing this module.

### Blocked — the erlang-backend gaps

> **Closed (2026-09-26).** Both backend gaps below closed during fronts 05 and 06,
> and the last two reds (`request/6`) closed with front 04's Step 10 — see the
> erlang-only paragraph under § Module tree. Only the toolchain gap (a BUILT
> program neither ships nor loads a sidecar) is still open. The text below is
> kept for the reasoning it records.

> **Updated during front 05 (2026-09-21).** The two gaps below were CLOSED by a
> compiler change that landed mid-front: a module-level `val` with a side effect
> now runs on erlang (it *is* the module body — evaluated once, in declaration
> order, at load, cached in `persistent_term`, with the init emitted in every
> mode), and a method on a host-supplied `behavior` now dispatches through the
> value. Measured against the rebuilt binary with front 05 in the tree:
> `botopink test` 87/87 and `botopink test --target erlang` 85 passing / 2
> failing. The six registration reds are gone and `server_test.bp` compiles for
> the first time. The two remaining erlang reds are `{badkey,param}` /
> `{badkey,query}` — `request/6` in `rakun_runtime.erl` builds a map carrying
> `method`, `path`, `params`, `query`, `headers` and `body` but no member funs,
> so `req.param("name")` now dispatches and finds nothing. That is rakun's own
> line, in front 04's file, and front 05 does not touch it. (**Front 06,
> 2026-09-21:** a third gap opened and closed inside this front's window — the
> compiler broke a record field read on erlang, reddening nine rakun cells with
> `{error, badarg}` and an empty RUN LOG; the fix landed in the shared checkout
> during step 5 and the row went from 200/9 to 250/2. Steps 1 to 4 of front 06's
> CHANGELOG entries are reported against the 200/9 baseline and say so.)
> `targets` stays
> `["commonJS"]` until the front that re-measures the whole library against the
> new compiler makes that call — not a front mid-flight. The text below is
> front 04's and is kept for the reasoning it records.

### Blocked — two erlang-backend gaps, neither rakun's

Both are in `botopink-lang`'s erlang emitter and neither can be worked around
from this repository. They are why `botopink.json` does not yet list `erlang`.
A third gap is the toolchain's, and it is two halves: `shipErlSidecars` is
called only from `test_cmd.zig`, so a `botopink build --target erlang` copies no
`.erl` sidecar at all; and `__bp_load_siblings/0` is emitted only under the TEST
flag (`codegen/erlang.zig`), so even a hand-copied sidecar would not be loaded.
Measured on `examples/rakun`: `botopink build --target erlang` exits 0, emits ten
modules carrying all sixteen `rakun_runtime:<fn>` qualifiers, ships no
`rakun_runtime.erl` and emits no loader — so a BUILT rakun program dies with
`undefined function rakun_runtime:serve/2`. Front 04 is fully exercisable through
`botopink test --target erlang`; it cannot demonstrate `botopink run` serving
HTTP on the BEAM until the `build` path ships and loads the sidecar too.

1. **A module-level `val` with a side effect never runs.** The component
   decorators `@emit` `val __rkScan_<Type> = rkScan("<Type>");` and
   `val __rkRoute_<Type>_<m> = rkRegisterRoute(…);` — module-load
   self-registration, which is what the node row does. On the erlang row a named
   module-level `val` is emitted as a 0-arity function that is called on each
   READ (`codegen/erlang.zig`, `topValForms`), and nothing reads these; the
   `'_botopink_main'/0` wrapper that would evaluate `_`-named top-level
   statements is not emitted in test mode at all. The evidence is in the output:
   `Warning: function '__rkScan_GreetRepo'/0 is unused`. So on erlang no
   component is scanned and no route is registered, and `di_test.bp`,
   `router_test.bp` and `overlapping_routes_test.bp` fail their registration
   assertions. `test/erlang_runtime_test.bp` therefore registers inside a test
   block rather than at module level.
2. **A method on a host-supplied `behavior` value does not dispatch.**
   `req.param("name")` where `req: Request` (a `behavior` with no in-module
   implementor — the host builds the value) lowers to a bare LOCAL call
   `param(Req, <<"name">>)`, which is undefined in the emitting module:
   `server_test.erl:57:40: function param/2 undefined`. `server_test.bp` does not
   compile on the erlang row because of it. The erlang `request/6` map already
   carries `method`, `path`, `params`, `query`, `headers` and `body`, so closing
   the gap is an emitter change, not a runtime one.

## The file-convention route table

`modules/rakun-app/src/file_router.bp` is the second routing model, beside — not
instead of — `#[restController]` + `#[getMapping]`. A URL comes from where a
file sits: `layout.bp` wraps everything below it, `page.bp` makes the route
public, `(group)` is transparent to the URL, `@slot` renders into a named prop
of the parent layout, `_private` is excluded from routing and
`[slug]` / `[...slug]` / `[[...slug]]` capture instead of matching.

**The grammar, the wire and the matcher are the bundled library `routing`'s**
(decision 115, `01-std/04-routing-lib`): `segment` (`parseSegment`, `parsePath`,
`patternOf`, `slotOf`, `pathProblem`), `table` (`RouteEntry`, `writeTable`,
`parseTable`) and `match` (`matchPath`, `layoutChain`, `paramOf`, `RouteMatch`),
imported `from "routing"` with no `dependencies` entry — the browser's router
imports the same code. Their tests moved with them. The sections below describe
the behaviour rakun relies on; the code is `libs/routing/src/`. `file_router.bp`
keeps the registry, the markers, `PageContext` / `LayoutProps` / `contextOf` and the
scan.

**Why the decorator takes the directory as a string.** botopink compiles only
declared modules, so a `.bp` file is not loadable by path, and `@Decl` carries
no source location — a decorator cannot learn which file it was written in. The
router is therefore REGISTRATION-driven: the app-relative directory of the
convention file reaches the marker as an argument, and the scan checks that
argument against the real tree under `appDir`.

### The segment grammar

`parseSegment` is the only place the bracket and parenthesis spellings are
decoded, and it is pure and total. `parsePath` splits an app-relative directory
into `Segment`s and HALTS on one that may not be registered; the refusal text is
`pathProblem`'s, a function of its own, for the reason `durationProblem` is one
(a test can read the message without the halt taking the test down).
`patternOf` drops groups and slots and keeps the bracket spelling, so
`(marketing)/about` is `/about` and `dashboard/@team/settings` is
`/dashboard/settings` with `slotOf` answering `team`.

| Folder | `SegmentKind` | `name` | In the URL |
|---|---|---|---|
| `blog` | `Static` | `blog` | `blog` |
| `[slug]` | `Dynamic` | `slug` | `[slug]` |
| `[...slug]` | `CatchAll` | `slug` | `[...slug]` |
| `[[...slug]]` | `OptionalCatchAll` | `slug` | `[[...slug]]` |
| `(marketing)` | `Group` | `marketing` | — transparent |
| `@team` | `Slot` | `team` | — the entry's `slot` field |
| `_drafts` | `Private` | `drafts` | — refused on a registered path |

Neither `|` nor a newline may appear in a segment name: they are the wire
format's field and record separators, and `pathProblem` names the segment that
holds one.

### The wire format

The table crosses the boundary as a LINE-ORIENTED BLOB, not as JSON: std's
`json` is `string -> @Result<string, string>` with no structured walker, and the
parser has to compile to the BEAM as well as to the browser. One record per
line, `\n`-separated, in registration order:

```text
kind|pattern|slot|verb
```

| Letter | Convention | Registered by |
|---|---|---|
| `L` | `layout.bp` | front 22 |
| `T` | `template.bp` | front 22 |
| `P` | `page.bp` | front 22 |
| `D` | `default.bp` | front 22 |
| `R` | `route.bp` | front 25 |
| `S` | `loading.bp` | front 30 |
| `E` | `error.bp` | front 31 |
| `N` | `not-found.bp` | front 31 |

**Trailing empty fields are dropped.** A root layout is `L|/`, a slot entry is
`D|/dashboard|team` and a handler is `R|/api/posts||GET`. That is what makes the
front's rule "no line terminates with a trailing `|`" true of the common record,
whose slot and verb are both empty; a fixed four-field record would end in `|`
by construction. `parseTable` reads a short line back as empty fields, so the
round trip is unaffected — and no consumer splits a line by hand, because
`parseTable` IS the reader on both rows.

### The matcher

`matchPath(table, pathname) -> ?RouteMatch` and
`layoutChain(table, pattern) -> RouteEntry[]` are botopink, compiled to both
targets. Precedence is applied SEGMENT BY SEGMENT, highest first — static (3),
dynamic (2), catch-all (1), optional catch-all (0) — and compared
lexicographically, so `/blog/new` beats `/blog/[slug]` and `/shop/[id]` beats
`/shop/[...rest]`. Two candidates with the same score are decided by
REGISTRATION order, the rule `rkDispatch` already follows.

- A route is PUBLIC only when a `P` or an `R` entry claims it. A pattern
  carrying nothing but an `L` entry answers `null`.
- A slot entry (`slot != ""`) is not a candidate: front 61 matches it separately
  against the same URL.
- `/shop/[...slug]` does not match `/shop`; `/docs/[[...slug]]` matches `/docs`
  with `rest` empty.
- `layoutChain` walks the pattern's ancestors root-first. Group segments never
  appear, because `patternOf` dropped them before the entry was written.

**Read a bound parameter with `paramOf(m, name)`, not `m.params.at(name)`.** A
`RouteMatch` reached through the optional binder — `if (matchPath(…)) { m -> … }`
— has lost its type at that name, so `m.params.at(…)` lowers to a property read
and `.unwrapOr` is not a function on it. `paramOf` takes a TYPED parameter and
is the form fronts 23 and 26 should use. The same rule bit `parseTable`: a `val`
bound inside a `loop` lambda needs its annotation (`val f: string[] = …`).

### The registry, and why this front ships a `.mjs` and an `.erl` where front 05 refused to

Front 05 wrote its readers in botopink and shipped no sidecar, for three
measured reasons: `botopink test` compiles every `test/*.bp` on BOTH rows with
no per-target gate, so a cell carrying only an `@External.Erlang` form is a
located node-row diagnostic at its CALL SITE; `runtime.mjs` is frozen, so an
erlang-only cell has no node twin; and `shipErlSidecars` ships only a sidecar
whose atom appears in emitted output, so an unreferenced one is skipped
silently. All three still hold. None of them says "never ship a sidecar" — they
say **a cell with one host form is a compile error, and a cell nobody names is a
run-time death**.

This front's work is not front 05's. Front 05's was PURE: document readers, one
implementation over `std`, and a sidecar would have been a second copy of
something botopink can do. A REGISTRY is not pure. botopink has no top-level
mutable state, which is the same reason `runtime.mjs` holds the scan list and
the router table; and a registered render function is a CLOSURE, which no string
property table can hold. So the table lives in the host on both rows:
`src/file_router.mjs` and `src/sidecars/rakun_file_router.erl`.

What makes the shape legal here:

- **Every cell carries both forms.** `rkAppRegisterPage` / `…Layout` /
  `…Template` / `…Default` / `…Handler`, `rkAppTable`, `rkAppCount`,
  `rkAppHasRender`, `rkAppRender` and `rkAppReset` each declare an
  `@External.Node("./file_router.mjs", …)` and an
  `@External.Erlang("rakun_file_router", …)`. Neither row has a call with no
  binding, so neither row reds.
- **`runtime.mjs` is frozen; `file_router.mjs` is this front's own file.** The
  freeze is on a file, not on the idea of a node host.
- **The atom is named in emitted output.** `file_router.bp` is compiled and
  emits `rakun_file_router:register_page(…)`, so `shipErlSidecars` finds and
  copies `src/sidecars/rakun_file_router.erl` — verified by LOOKING, at
  `.botopinkbuild/test-out/rakun_file_router.erl`, not by trusting exit 0. The
  atom is `rakun_file_router` and never `file_router`, because rakun emits
  `rakun/file_router` and a matching sidecar is skipped in silence.

**"The same matcher compiled twice" is one matcher, not two.** The spec's phrase
means the botopink matcher compiled to two TARGETS; it does not mean a JS
matcher beside an erlang one. The two host files hold no grammar, no wire format
and no matching: each cell is handed the finished `kind|pattern|slot|verb` LINE
and appends it beside its function, and `table()` joins the lines back. Neither
host knows the format. That is what makes "the two sides cannot disagree about
which route a URL is" a property rather than a hope — and it is the same
conclusion front 05 reached, applied to the half of this front that is pure.

**What a BUILT program still cannot do on the BEAM.** `shipErlSidecars` is
called only from `test_cmd.zig`, so `botopink build --target erlang` copies no
`.erl` sidecar and `__bp_load_siblings/0` is emitted only under the TEST flag
(front 04's § Blocked, third gap). `rakun_file_router.erl` inherits that
exactly: it is shipped and loaded under `botopink test --target erlang`, where
every assertion in this front runs, and a BUILT erlang program would die with
`undefined function rakun_file_router:table/0` for the same reason a built one
already dies on `rakun_runtime:serve/2`. Nothing in this front makes that worse
and nothing in this front can fix it — it is the toolchain's.

**`targets` still reads `["commonJS"]`, deliberately.** All 48 of this front's
assertions are green on both rows, but the member's erlang row still carries
front 04's `request/6` reds (`{badkey,param}` / `{badkey,query}`), not this
front's. Widening `targets` now would move a known red into `botopink-lib-test`
rather than fix anything, which is the call front 04 and front 05 each made for
the same reason, and front 06 after them. `erlang` joins in the change that
closes them. (The counts this paragraph carried were front 22's and are
superseded by the measurement in § Tree.)

**Table ownership on the BEAM.** An ETS table dies with the process that created
it, and a registration runs in whatever process loaded the module, so
`rakun_file_router` creates its tables in a dedicated owner process registered
under `rakun_app_routes_owner`; a second caller losing the race finds the table
already there. It deliberately does not reuse `rakun_runtime`'s supervision
tree: the two sidecars are shipped independently, and a file-convention program
that never touches the DI container should not start an application to hold four
rows.

### The four markers

`#[layout(seg)]`, `#[template(seg)]`, `#[page(seg)]` and `#[defaultView(seg)]`
live in `file_router.bp` because `decorators.bp` is frozen — the same reason
`#[configurationProperties]` lives in `config.bp`. `default` is a reserved
keyword, so the `default.bp` marker is `#[defaultView]`: the only name in the
set that does not match its file. Front 25's verb markers register `route.bp`
handlers into the same table as `R` records, through `rkAppRegisterHandler<Res>`,
which is declared here and generic over the response type — so this front never
learns what a `HandlerResponse` is and front 25 declares no host cell.

Each body `@emit`s the registration, `@emit`s the per-route parameter accessor,
and then enforces placement, in that order: the `@emit`s run first because a
failed outcome discards the contributions.

| Written | Refused with |
|---|---|
| `#[page]` on a type | `#[page] must annotate a function` |
| `#[page]` on a fn returning `Element` | `#[page] must annotate a fn returning @Task<Element> — every page is async so the render pipeline has one shape to drive` |
| `#[layout]` on a fn returning `@Task<…>` | `#[layout] must annotate a fn(props: LayoutProps) -> Element — a layout is synchronous, only a page is a @Task` |
| `#[page()]`, `#[page(1)]` | the automatic argument check, with no code in this front |

Three measurements shape these bodies and one of them is new:

- **A named function used as a VALUE does not lower on the erlang row.**
  `rkAppPage("blog", blogPostPage)` compiles on node and is
  `variable 'BlogPostPage' is unbound` on erlang. The markers therefore emit
  `{ route -> blogPostPage(route) }`, which is the same value, lowers on both,
  and is what `decorators.bp` already emits for a controller method.
- **`decl.returnType` carries no type argument.** It is `"Task"` for
  `-> @Task<Element>`, `"Element"` for `-> Element` and `""` for a type. So a
  page is checked to BE a `Task` and a layout to be anything that is not one;
  the required spelling is in the message, which is as close to "naming the
  required return type" as the reflection allows.
- **An `@emit`ted module-load `val` lands at the END of the emitted module**,
  after every hand-written module-level `val`. A registration therefore cannot
  be snapshotted in the module that hosts it — which is why the markers have
  their own test file: `botopink test` runs each test FILE in its own process
  (measured), so `test/file_router_markers_test.bp` never sees the
  `rkAppReset()` the registry-cell assertions next door need.

### The emitted parameter accessor

`#[page("blog/[slug]")] pub fn blogPostPage(…)` also emits

```bp
pub fn blogPostPageParams(route: PageContext) -> #(slug: string) {
    val slug = ctxParam(route, "slug");
    return #(slug);
}
```

A catch-all emits `val slug = ctxRest(route);` and types the field `string[]`; a
route with no dynamic segment emits `-> #()`. The reads go through `ctxParam` /
`ctxRest` rather than `route.params.at(name).unwrapOr("")` for the reason
`paramOf` exists: an inline read off a value whose type was lost lowers to a
property read and `.unwrapOr` is not a function on it. A consumer therefore
imports `ctxParam` and `ctxRest` beside the markers, the way a module declaring
components imports `rkScan` and `rkSingleton`.

The accessors only exist under `botopink test`, never under `botopink check`:
`check` skips decorator invocation and reports every `@emit`ted name as unbound.
That is a known gotcha, not this front's.

### The scan

`scanAppDir(root, appDir) -> ScanReport` reads the real tree and answers the
entries it implies, the project-root `middleware.bp` and the problems. It is
BOTOPINK, over `std`'s `fs`, and not the two host files the front's text puts it
in — for front 05's reasons, applied one level up: a scan written twice can
disagree twice, and an erlang-only cell cannot be asserted from a `.bp` test at
all, so every rule below would have been taken on trust. `fs.list`, `fs.exists`
and `fs.stat` each carry both host forms, so one implementation answers on both
rows and `test/file_router_scan_test.bp` proves it against real fixture trees.

`appDir` is CONFIGURATION: `appDirOf()` is `rkProp("onze.appDir")` with `app` as
the default, so moving a tree between `app/` and `src/app/` changes one config
line and no source — asserted by scanning the same fixture under both layouts
and comparing the tables.

| Rule | Refusal |
|---|---|
| a segment holds `page.bp` and `route.bp` | ``rakun routing: `both` holds both page.bp and route.bp — a segment is a page or an endpoint, never both`` |
| two root layouts' subtrees claim one URL | ``rakun routing: `/about` is claimed by both `(marketing)` and `(shop)` — two root layouts whose subtrees match one URL`` |
| a registered segment with no directory | ``rakun routing: `blog/[id]` was registered by `typoPage` but there is no directory `app/blog/[id]``` |
| a directory holding a convention file that registered nothing | ``rakun routing: `app/blog/[slug]` holds page.bp but nothing registered it — the marker's argument is what puts a route in the table`` |
| a `_`-prefixed directory | skipped by `walkSegments`; nothing inside is registered, `page.bp` included |
| a project-root `middleware.bp` | discovered as `report.middleware`, with no `pub mod` line naming it, and handed to front 07. A project with none scans clean and says nothing |

A refusal is a STRING, not a halt, for the reason `durationProblem` is a
function of its own: front 50's CLI prints it and stops, a boot check prints it
and stops, and a test reads it without the halt taking the test down.

`rkAppRegisterSource(seg, fnName)` is what makes the third row possible. The
wire record carries the URL PATTERN, not the app-relative directory, so the raw
pair each marker was written with is kept beside the table — `rkAppSources()`
answers `seg|fnName` lines — rather than squeezed into a fifth field of a
four-field record.

**A directory walk is rakun's, not std's.** The front's text says front 01
closes it; `libs/std` has no `walk` today, so `childDirs` / `walkSegments` are
here, over `fs.list`. A name is a directory when listing it succeeds:
`fs.stat` would say so more directly, but its `FileStat` carries an `i64` field
and an integer literal is `i32` with no widening, so the `catch` value of a
`try fs.stat(…)` cannot be written at all.

## The request context

`modules/rakun/src/request_context.bp` is the scope every server-side read of a
cookie or a header goes through. Before it, a `Request` existed only inside the
function the router dispatched to: a `#[service]` three calls down could not see
it, a page the SSR pipeline renders is never handed one, and `Response` is
`(status, body)` with `http.bp` frozen, so there was no field to put a
`Set-Cookie` in.

**The scope is a FRAME with an EPOCH, not a process.** On the BEAM a request is
served by a process and process-local state is very nearly request scope — but a
keep-alive connection process serves many requests in sequence, so process
identity is not request identity. A scope implicit in the process leaks the
previous request's cookies into the next one. So the frame is one explicit key
carrying a monotonic `epoch`, and every handle minted from it carries the epoch
it was minted with; a handle used after `endRequest`, or from the next request on
the same connection, RAISES rather than writing into somebody else's response.
That is the first test in `test/request_context_test.bp`, deliberately.

**`RequestScope` owns the context: `implement @Context<RequestBase>`.**
`RequestBase` (`pub type RequestBase {}`, a marker with no fields) is the base
a request hook's `use`s anchor at — `-> @Component<RequestBase, T>` (decision
128, front 24's guide § 4.4) — so the one-base rule refuses a request hook
inside a jhonstart component (`ElementBase`) at the second `use`. No accessor
here is a hook yet: every reader below is an ordinary function that raises
outside a frame, and turning one into a hook is a front of its own (every caller
would then need a `@Component<RequestBase, …>` return).

| Verb | Who calls it | What it does |
|---|---|---|
| `beginRequest(scope)` | front 04's acceptor, front 23's SSR pipeline, front 24's action dispatcher, front 07's chain | writes the one frame key — `rakun_request` in the serving process's dictionary on the BEAM, one module global on node — and answers the epoch. Over an existing frame it RAISES, naming the outer scope's path |
| `setPhase(p)` / `requestPhase()` | the same dispatchers | one phase, stored once. Front 12's `rkCachePhase()` is to read this slot, not a second one |
| `endRequest()` | the same caller, always, including on the failure path | answers the queued `Set-Cookie` lines and erases the key. With no frame it RAISES |

**Reading outside a request is a hard failure.** `requestPhase()` with no frame
does not answer a default, does not answer `null` and consults no property: it
raises `request context is not established`. There is no lenient mode, no
`…Or(default)` and no predicate to branch around it — a predicate is an escape
hatch with a different spelling, and the milestone's standing rule is that the
most restrictive behaviour wins with no knob around it. A library that has to
work inside and outside a request takes the values as parameters. `requestLive()`
exists for a DISPATCHER deciding whether it already opened a frame, not for an
accessor deciding whether to answer.

### `RenderHooks` — the one seam, and it points inwards (decision 77)

A framework built on this pipeline has three things to add to a document:
stylesheet `<link>`s and blocking scripts in the head, the deferred bundle tags
after the payload, and a style sink that decides WHEN the sheet is serialised.
None of it may be reached for from here — an edge from rakun to a bundler would
make the server depend on the toolchain that packages it, and rakun would stop
being usable without one.

```bp
pub type RenderHooks(
    headExtra: fn(string) -> string,           // route -> extra <head> markup
    bodyExtra: fn(string) -> string,           // route -> markup after the payload tag
    islandAttr: fn(i32) -> #(string, string),  // ordinal -> the marker pair
    openSink: fn() -> i32,                     // before anything renders
    collectHead: fn() -> string,               // once, after the shell
    collectChunk: fn(string) -> string,        // holeId -> the block before that chunk
    closeSink: fn() -> string,                 // after the last chunk
)
pub fn defaultHooks() -> RenderHooks
pub fn setHooks(h: RenderHooks) -> i32
pub fn hooks() -> RenderHooks
```

`defaultHooks()` is a working document: no extra tags, the marker pair of
`contracts.md § 2`, and a sink that collects nothing. The record is filled FIELD
BY FIELD — `withHeadExtra` / `withBodyExtra` / `withIslandAttr` /
`withCollectHead` / `withSink` each replace one field and leave the other six at
their defaults, because botopink has no record-update expression and a caller
spelling all seven to change one is a caller who will get one of them wrong.

`grep` `modules/rakun/src/` for `onze` and the only hits are the `data-onze-*`
marker names and `__onzeFill` — `contracts.md § 2` STRINGS, not module
references. `Onze.run` installs its own record at boot, one line in ITS code;
`islandAttr` is jhonstart front 29's, because the marker belongs to whoever
decides which components are islands, while the ordinals are assigned here.

**`void` is not a value in botopink**, so `openSink` answers `i32` — the shape
every rakun cell that does something rather than computing something already
has. The front's text spells it `fn() -> void`.

**`emilia.flush()` is not called here and may not be.** The front's § *The
document* still says the pipeline calls it once per document; decision 77
replaced that with the four sink fields, filled by front 69 and installed by
`Onze.run`, so `repository/rakun/` names no module of onze and none of emilia
either. The consequence is visible in one acceptance: a document rendered
through `defaultHooks()` carries **no** `<style>`, where the front's text says
"exactly one". The suite asserts zero for the default and exactly one through a
hooks record whose `collectHead` answers a block.

### Step 4 — the document and the payload

```bp
pub type Payload(build, pathname, pattern, params, query, table,
                 islands, actions, styles, holes, dynamic, kinds, slots)
pub fn writePayload(p: Payload) -> string
pub fn payloadEscape(json: string) -> string
pub fn document(head: string, body: string, p: Payload) -> @Task<string>
```

The payload is one `<script id="__onze" type="application/json">`, the last
thing in `<body>` before the client bundle, and its key table is
`contracts.md § 2` — `v b p r m q t i a s h d`, plus `k` and `z`, which this
front ALLOCATES and fronts 60 and 61 write. `k` and `z` are separate blobs
joined on `pattern` rather than extra columns in the route table, so contract 1
stays untouched and its round-trip test keeps testing four fields.

`kinds` and `slots` are fields of the record because the front's step-4 sketch
of `Payload` predates its own key table by two keys: a key with no field cannot
be written.

**Payload escaping.** `<`, `>` and `&` become `\u003c`, `\u003e`, `\u0026`,
and U+2028 / U+2029 become `\u2028` / `\u2029`. `</script` is therefore
UNREPRESENTABLE inside the block rather than filtered out of it, which is the
property that makes an inert `application/json` script safe to carry
attacker-controlled strings. The two line separators are found BY CODE POINT and
never by a literal: a non-ASCII string literal raises `badarg` on the erlang row
before any of this front's code runs, so the needle could not be written. The
positive case — a payload actually carrying U+2028 — is for the same reason not
expressible as a cell, which is front 62's non-ASCII-cookie gap one library
later; the guard is asserted on the escape output instead.

**The round trip is one test, not two half-tests.** `rkSsrPayloadKeys` and
`rkSsrPayloadText` parse the emitted block with a JSON parser this front did not
write — `JSON.parse` on node, OTP's own `json:decode/1` on the BEAM (OTP 27 and
later) — so a document whose payload is not valid JSON fails on BOTH rows. The
keys come back SORTED, because a map has no order and an object's insertion
order is not the contract; the field SET is. A reader of our own would have been
a second implementation of the thing under test, which is the failure mode the
round trip exists to prevent.

**Island ordinals are assigned here, in render order** — `i0`, `i1`, … —
through `nextIslandOrdinal()`, and the attribute pair is read through
`RenderHooks.islandAttr`, so the marker and the payload index cannot disagree.
Hole ordinals are `h1`, `h2`, … in shell order. Neither is derived from a route,
a pattern or a position in the tree; fronts 29, 30 and 68 designed against that.

**What is NOT written here.** The build id `b` is front 03's content hash of the
build, which does not exist on this binary; `Payload.build` is whatever the
caller passes and `render` reads `rakun.build.id` from front 04's property
table. The contract-4 class-name fixture — the literal hex class the document's
`<style>` and the payload's `s` must share with
`emilia/test/integration_test.bp` — is not asserted here either: it needs emilia
to be a dependency of rakun, and `s` arrives through the style sink's
`emittedClasses`, so the assertion belongs to front 69 or 68, where both sides
of the comparison exist.

### Steps 5 and 6 — the chunk protocol and the two entry points

```bp
pub fn render<El>(v: ElementView<El>, pathname: string, query: string) -> @Task<RenderedPage>
pub fn renderAll<T>(thunks: Array<fn() -> @Task<T>>) -> @Task<Array<T>>
pub fn markupAll<El>(v: ElementView<El>, resolved: Array<El>) -> string[]
pub fn streamChunks(head, shell, ids: string[], markups: string[], p: Payload) -> RenderedPage
pub fn beginRender(id, pathname, query, strict) -> i64
pub fn endRender() -> string
```

**The phase word is not bookkeeping.** `render` enters
`setPhase(RequestPhase.Render)` and restores the previous phase when it is
done, because that is the same word front 12's `rkCachePhase()` reads to decide
whether a revalidation is legal. The phase table of `contracts.md § 5` is
ENFORCED, and the suite proves it by writing a cookie from a render and reading
the refusal.

**`beginRender` / `endRender` are two halves, deliberately.** front 62's
contract says `endRequest()` must run on the failure path too, or the next
request on a keep-alive connection starts inside this one's frame. botopink has
no `finally` and a raise is not catchable from a `.bp` body, so the bracket is
the DISPATCHER's; this front provides the two halves rather than pretending one
call can hold it. On the BEAM the frame dies with the serving process, which is
why it is process-local; on node it would survive, which is why the rule is
written here as well as in front 62.

**`@Task` is not concurrency on the target this front compiles for.** It
lowers EAGERLY on erlang (decision 120), so a task is a value that has already
been computed and two of them awaited together have already run in sequence, at
full latency — and no assertion over the markup would ever say so. A `@Task` fn
also cannot `await` inside a `loop` or a closure. So the pipeline never awaits
in a loop and never hands anything an already-started task: it builds an
`Array<fn() -> @Task<El>>` — unstarted THUNKS — and `renderAll` gathers them
in ONE await, one spawned process per thunk. The PARAMETER TYPE is what makes
"no call site passes an already-started task" checkable: a value does not fit
where a function is required.

The suite measures it: two 50 ms loaders finish under 100 ms on the row that
spawns and take 100 ms on the row that cannot, and the cell asserts
`fast == concurrentRow()` rather than claiming one shape for both. The same
test written over already-started tasks takes 100 ms on BOTH rows and looks
correct in every other respect, which is the whole reason the thunk type is
pinned.

**The streaming entry is three calls and not one, and that is a compiler gap.**
A parameter typed `Array<fn() -> @Task<El>>` in a function that also takes an
`ElementView<El>` is refused with `generic-arg-skip-forbidden: cannot skip a
defaulted argument while providing a later one`, reported on the token AFTER the
parameter and at any position in the list; each half compiles alone, the two
together do not, and wrapping the thunk in a record (`Hole<El>`) hits the same
refusal. So the gather keeps its own function and the chunk protocol keeps its
own, where nothing is generic:

```bp
val resolved = await renderAll(bodies);
val page = streamChunks(head, shell, ids, markupAll(v, resolved), payload);
```

1. **Shell** — doctype, head, open body, the composed tree with each boundary
   rendered as `<div data-onze-h="h1">…fallback…</div>`; the payload's `h`
   lists every hole still open.
2. **Fill** — one per boundary, in RESOLUTION order:
   `<template data-onze-f="h1">…</template><script>__onzeFill("h1")</script>`.
3. **Tail** — the payload script, the sink's closing block, the body extra.

The ids stay in SHELL order while the fills go out in the order the gather
SETTLED in — which a gather by index cannot also answer, so the host records it
on the side and `settledOrder()` reads it back. Two boundaries that resolve out
of order therefore produce two fill chunks in resolution order, each carrying
its own markup, and every id in `h` is filled by exactly one chunk. A boundary
that resolved before the shell flush is simply not in the list: it was rendered
inline, and there is no hole and no fill chunk for it.

`__onzeFill` lives in `ssr.mjs` and is idempotent by construction — a second
call for one id finds no template, or no hole, and leaves the DOM unchanged.
**Its DOM-level assertion is not a cell in this suite and cannot be**: it is
browser code, so there is no erlang twin to pair it with, and a node-only
`declare fn` would red the erlang row at its call site (front 05's first
measurement). What this suite asserts is the PROTOCOL — one fill chunk per hole
id, the `<template>` + `<script>__onzeFill("…")</script>` shape, the ids. The
DOM half belongs to front 68's bundle test, where a DOM exists.

### What jhonstart front 26 consumes from this front

Front 26 (the client router) and the chain behind it — 27 to 32 — wait on this
front. This is the surface they may rely on; none of it changes without a note
here.

| What | Where | Shape |
|---|---|---|
| The element adapter | `ElementView<El>` + `nodeView` | front 26 writes ONE adapter for jhonstart's `Element`: `make`/`tagOf`/`valueOf`/`attrsOf`/`childrenOf` plus front 94's `isVoidTag`/`isRawTextTag`. Every field is a LAMBDA (`{ t -> isVoidTag(t) }`), never a bare function name |
| The escaping walker | `renderNode(v, e)` · `raw(v, html)` | the only renderer any milestone path may call on untrusted data; `renderToString` escapes nothing and still writes `</input>` |
| Composition | `compose(v, chain, route, nav, page)` | `chain` is front 22's `RouteMatch.chain`, already root-first. `nav` is the navigation counter the `data-onze-t` key carries |
| The layout depth | `selected()` | front 26's `selected`, root layout `0`. A call and not a field of `LayoutProps`, which is front 22's three-field record |
| The payload | `Payload` · `writePayload` · `payloadEscape` · `payloadOf(document)` | `contracts.md § 2` verbatim, `v`=1. `p`/`m`/`q`/`r` are front 26's router state one-to-one; `segments` is derived from `r`, never transported |
| The document | `document(head, body, p)` | `head` is front 32's `renderHead(m)` output. The body sits inside `<div data-onze-root="">` |
| The seam | `RenderHooks` · `defaultHooks()` · `setHooks` · the six `with*` fillers | front 29 defines `islandAttr`; `Onze.run` installs the record |
| Islands | `nextIslandOrdinal()` · `islandId(n)` · `island(v, h, n, inner)` | ordinals `i0`, `i1`, … in render order, assigned HERE; the component name and props live in the payload's `i`, never on the element |
| Holes | `nextHoleOrdinal()` · `holeId(n)` · `holeMarker(v, n, fallback)` · `fillChunk(id, markup)` | ordinals `h1`, `h2`, … in shell order, assigned HERE, never route-derived |
| The page | `RenderedPage` · `chunkCount` · `chunkAt` · `bodyOf` · `toResponse` | read a chunk through the typed accessor, not `page.chunks.at(i)` |
| Entry points | `render(v, pathname, query)` · `beginRender` / `endRender` | `endRender()` runs on the failure path too — it is the dispatcher's bracket |
| The search params | `searchParams(route)` · `searchParam(route, name)` | reading them MARKS the render dynamic |

**One call-site rule for all of it, and it only shows on the erlang row:** a
function-valued record field must be read into a local before it is called —
`val tagOf = v.tagOf; tagOf(e)`, never `v.tagOf(e)`.

**One hole front 26 should know about.** `searchParams(route)` marks the render
dynamic; `route.query` is a public field of front 22's `PageContext` and a
direct read of it is a field read this front cannot intercept. The marking is
therefore enforced for everyone who goes through the accessor and for nobody
who does not, which is weaker than the front's own text ("the marking is done by
the accessor, not by a developer remembering to declare it"). Closing it means
either dropping `query` from `PageContext` or making it private — both are front
22's file, and neither is this front's to change. Recorded, not smoothed over.

### The gate's own greps

`examples/rakun-ssr/` is the consumer half, and it is a RUN rather than a claim:
`botopink run` prints the document, and the program halts with a named refusal
if the title reaches the browser unescaped or the payload is not `v1`. (Since the
erlang-only move it builds but does not run: a built erlang program neither ships
nor loads its sidecars — § Module tree, "What the move costs".)

`scripts/git-hooks/lib/runner-standalone.sh` stage 1b enforces three claims of
this front's *Definition of done*, because each of them is one edit away from
being false and none of them is visible in a test:

- `ssr.bp` contains no `renderToString` — a single call is the whole hole.
- `modules/rakun/src/` imports no module of onze and names `onze` only in the
  `contracts.md § 2` strings (`data-onze-*`, `__onze`, `__onzeFill`) and front
  22's `onze.appDir` property key (decision 77).
- `ssr.bp` spells no void tag — the set is front 94's `isVoidTag`, arriving as
  an `ElementView` field.

### Language notes this module is written around

Beyond the two call-site rules above, five measurements shaped this file and
each of them cost a red:

- **`await` inside an `if`/`else` block of a `@Task` body is emitted inside
  a NON-ASYNC arrow IIFE on the commonJS row** — botopink's `if` is an
  expression — and node refuses the file at LOAD with `SyntaxError: await is
  only valid in async functions`, taking the whole test FILE down rather than
  one cell. `render` therefore looks the page function up for both arms and
  awaits once, at the body's own level.
- **The optional binder is a closure.** `if (matchPath(…)) { m -> … }` may not
  `await` inside it, so `render` unpacks the match into locals and every await
  happens below.
- **`xs.at(i).unwrapOr(…)` reads the element back UNWRAPPED** both inside a
  function generic in `El` and at a call site where the array came off a RECORD
  FIELD — `{case_clause, <<"…">>}` on the erlang row. Read through a typed
  PARAMETER (`chunkAt(page, 0)`) or walk with a `loop` binder. It is the same
  shape `paramOf`, `headerOf` and `ctxParam` already exist for.
- **A local `val` or a PARAMETER may shadow a module-level `pub fn` of the same
  name for an IMPORTER.** A parameter named `raw` in `jsonString(raw: string)`
  made a test importing `pub fn raw` fail with `expected Node, got bool`. The
  parameters are `plain` and `text` now.
- **`std`'s `querystring` does LESS than `splitQuery` / `encodeQuery`, and that
  — not loading — is why the two bodies are still here.** `querystring.parse`
  does not percent-decode (`a=%20b` reads back as the literal `%20b`) and
  splits a chunk on EVERY `=`, losing the `=c` of `a=b=c`; `querystring.stringify`
  does not percent-encode, so `#("a b", "c;d")` serialises as `a b=c;d`. std
  says so itself — "the call site should pre-escape". `route.query` is a decoded
  dict and the form grammar cuts at the first `=`, so both differences matter.
  Swapping both bodies for the std calls leaves every OTHER cell in this
  repository GREEN, which is why the cell `splitQuery / encodeQuery
  percent-code, which std's querystring does not` exists: it reds on all three
  lines when the swap is made, measured. The percent codec is NOT written a
  second time — `percentEncode` / `percentDecode` are front 62's.

### Why this front ships BOTH host files where front 05 shipped none

Front 05's three measurements still hold and none of them is violated here:
every cell carries both forms, so neither row has a call with no binding;
`runtime.mjs` is frozen but `request_context.mjs` is this front's own file; and
the atom `rakun_request_context` is named in emitted output, so
`shipErlSidecars` copies it — verified by looking at
`.botopinkbuild/test-out/rakun_request_context.erl`, not by trusting exit 0.

What decides the shape is front 22's test, and it is one question: **is the
thing being stored pure?** Front 05's config readers were — one implementation
over `std` answered both rows and a sidecar would have been a second copy of
something botopink can do. This frame is not pure. It carries a queue of
deferred THUNKS and a memo table of arbitrary typed VALUES, and no string table
holds either; the same sentence front 22 wrote about a registered renderer. So
the hosts hold a slot store, a keyed line list, a queue, a table and a counter —
and the phase table, both wire grammars, the cookie serialization, the draft
signature and every refusal message are botopink, compiled to both targets.
Neither host knows what a phase permits or what a cookie looks like, which is
what makes "the two rows cannot disagree about what a request context says" a
property rather than a hope.

**The module atom may not be `request_context`.** rakun emits
`rakun/request_context`, whose basename is `request_context`, and
`shipErlSidecars` skips a qualifier matching a module this build emitted —
silently. The sidecar is `src/sidecars/rakun_request_context.erl`, the same rule
that names `rakun_runtime` and `rakun_file_router`.

**An ETS area beside the process dictionary.** The frame is the serving
process's dictionary. Deferred work runs in a CHILD process, so its bookkeeping
can live in neither, and the shared area is ETS owned by a dedicated process —
`rakun_file_router`'s shape, for `rakun_file_router`'s reason.

### `headers()` and the dynamic marker

`headersWire` is `name\tvalue` lines, `\n`-separated, names already lowercased
by the dispatcher — and `headerLookup` lowercases again anyway, because a lookup
that trusts its caller is a lookup that answers `null` in production. A repeated
header is joined with `", "`, which is what RFC 9110 § 5.3 lets a recipient do
and what front 04's dispatcher already does for a repeated query key.

`headerNames`, `headerLookup` and `headerPresent` take the WIRE as a parameter,
so the grammar is unit-testable with no frame, no process and no socket; the
`Headers` handle is the frame-bound face of the same three.

`get` answers `?string` and `null` for an absent header — the one place this
front deliberately differs from `Request.header`, which is frozen at plain
`string`. A header that is absent and a header whose value is empty are
different questions, and a server that cannot tell them apart cannot implement a
conditional request.

**Read a header with `headerOf(h, name, fallback)`, not
`headers().get(name).unwrapOr(fallback)`.** The optional a record method answers
LOSES ITS TYPE when the receiver is itself a call or an unannotated local, and
`.unwrapOr` is then emitted as a bare local call — `unwrapOr is not a function`
on the node row, `function unwrapOr/2 undefined` on the erlang one. Either
annotate the handle (`val h: Headers = headers();`) or go through `headerOf`,
whose PARAMETER is typed. It is the same shape `paramOf` already exists for in
`file_router.bp`, one type further out, and it is why every handle in
`test/request_context_test.bp` carries its annotation.

Every accessor that reads the in-flight request marks the render dynamic when
the phase is `Render` or `Handler` — `Middleware`, `Action` and `After` are
dynamic by construction and marking them would put a reason on a render that
never existed. `dynamicReason()` names the FIRST function to mark, which is what
turns "this page is not being prerendered" into a line of build output. The
frame's `strict` flag is set by front 60's prerenderer and by nothing else: a
dynamic read raises there, naming the function and the route.

### `cookies()`, and the `Set-Cookie` queue

Front 04's `rkSetReplyHeader/2` replaces by NAME, so it can carry one
`Set-Cookie` and no more. This front therefore queues fully serialized lines on
the frame and hands the list back from `endRequest()` as a `\n`-separated blob;
the dispatcher appends each line to the response as its own header. The host
holds a keyed line list — insertion-ordered, replaced by key, position kept on a
replace — which is the same primitive `set_reply_header/2` already is. Neither
host knows what a cookie looks like.

`cookieNames` / `cookieLookup` / `cookiePresent` take the header as a PARAMETER
and are pure, so the grammar is asserted with no socket. A chunk with no `=`
contributes nothing: a cookie the client never sent must not read as one it did.
Spaces around the separators are trimmed, a trailing `;` is skipped, the first
occurrence of a repeated name wins (RFC 6265 § 5.4), and a cookie NAME is
case-sensitive where a header name is not.

**`cookieDefaults()`'s `maxAge: 0` is a defect, implemented as specified.** RFC
6265 § 5.2.2 says a `Max-Age` at or below zero expires the cookie immediately,
so `serializeCookie(n, v, cookieDefaults())` writes a line the user agent
deletes on arrival — `maxAge: 0` is not the restrictive end of the lifetime
axis, it is the *deleting* end. The restrictive-and-correct default is to OMIT
`Max-Age`, which is a session cookie. The front's acceptance pins the literal
`s=a%20b; Path=/; Max-Age=0; HttpOnly; Secure; SameSite=Lax` and eleven fronts
cite this one, so the literal is honoured and the defect is written down rather
than silently corrected. Fronts 10 and 18 must pass their own `maxAge`;
`delete` is told apart from a defaulted `set` by its EMPTY value, not by its
`Max-Age`. Closing it is a one-line change in `serializeCookie` plus one
acceptance line, and it belongs to the front that owns sessions.

**Percent encoding is ASCII, and says so.** There is no byte type (front 01
recorded it) and `charCodeAt` answers a UTF-16 code unit on node against a
codepoint on the BEAM: two reasons the two rows cannot be made to agree about a
non-ASCII octet. (A third reason used to be listed — `std`'s `unicode` was
unreachable from here — and it is gone: `unicode.firstCodepoint` from a `test/`
file is green on both rows as of `4fe1747e`. `unicode.codepoints` would make the
two rows agree about a codepoint; widening `percentEncode` past ASCII is a
behaviour change and belongs to the front that owns the cookie grammar, not to a
cleanup.) A CONTROL character percent-encodes — that is how "a `Set-Cookie` line
cannot hold a newline" is kept true — and a character ABOVE printable ASCII
makes `serializeCookie` raise, naming the cookie and saying to encode the value
first. `percentDecode` decodes only into the printable range: a decoder that can
produce a control character is a decoder that can put a newline in a header, so
`%0A` stays `%0A`, which is lossless and round-trips.

### Draft mode and `connection()`

`__rakun_draft` is a SIGNED cookie, `token + "." + signature`. `isEnabled()`
recomputes the signature and compares it with `equalsConstantTime`, so a forged
or truncated cookie is simply not enabled and the comparison is not a signing
oracle — "constant time" here means no early exit and the same number of
comparisons whatever the inputs are, which is as much as a language with no byte
type can promise. An empty `rakun.draft.secret` makes `enable()` RAISE at the
first call: an unsigned bypass cookie is a public preview of every unpublished
draft on the site.

**Two deviations from the front's text, both from before front 01 landed.**
The signature is `hash.hmacSha256` (hex, not base64url; was `crypto.hmacSha256`)
and the token is `random.randomBytes(16)` from `io.random` (hex too; was
`crypto.randomBytes`). Both carry an `@External.Node` and an
`@External.Erlang` form and answer identically on the two rows, which is the
property that matters; the encoding is wider on the wire and nothing else. When
front 01 lands, `draftSign` is the one function to change.

The draft cookie does NOT use `cookieDefaults()` — its `maxAge: 0` would delete
the cookie on arrival. `draftAttrs()` gives it a day, because a preview bypass
with no expiry is a permanent hole in the published site.

`connection()` reads nothing and marks, which is its whole purpose: it is how a
route says "I am dynamic" without pretending to need a header. `draftBypass()`
is the one boolean front 60 reads to skip its prerendered entry, and it is the
only coupling between the two fronts.

### Deferred work — `after()`

`after(work)` pushes a thunk on the frame. `endRequest()` FREEZES a copy of the
frame under phase `After` and starts the work; the dispatcher writes the
response and then calls `drainAfter(budget)`, which reaps. A child can still
read the headers and the cookies of the request it belongs to — that is what
"frozen copy" means — and can write nothing: `cookies().set` and a second
`after()` both raise in phase `After`.

**This is the one place the two rows are not the same mechanism, and it is
stated rather than papered over.** On the BEAM each thunk is a `spawn_monitor`
child and a child that outlives `rakun.request.after.timeout` is KILLED, the
kill logged. Node has no process and cannot interrupt a synchronous function: it
runs each thunk in a try/catch with the same frozen copy installed, and a thunk
that OVERRAN the budget is counted and logged in the slot the BEAM kills into.
The counters and the log agree on both rows; the interruption is real on one and
after the fact on the other, and no assertion claims otherwise.

The Pid/Ref list lives in the parent's dictionary under its OWN key, not in the
frame — `endRequest` erases the frame and the children outlive it, which is the
whole point — and the request id is captured at `startDeferred` rather than read
in the reap, because by the time a child settles the frame is gone and a
deferred failure with no request to hang it on is a line nobody can act on.
`afterLog()` is what front 17 reads; until front 17 lands it is a `\n`-separated
blob of `after: failed <id> <reason>` and `after: killed <id> <budget>` lines.

A deferred child is a different PROCESS, so nothing it computes comes back
through a local: `rkReqShareBump` / `rkReqShareCount` / `rkReqSharePut` /
`rkReqShareGet` are the ETS scratch the front's own text names when it says "the
loader increments an ETS counter". `rkReqSleep` is a BLOCKING sleep —
`timer:sleep/1` on the BEAM, `Atomics.wait` on node — because front 01's `clock`
module does not exist yet and the deferred-work assertions need a thunk that is
still running.

### Per-request memoization — `request_memo.bp`

`memoize(key, load)` is `rkSingleton` one scope down: answer the stored value,
or run the thunk and store it. The table lives IN the frame, so it dies with the
request — a memo that survives a request is a cache, and caches belong to front
12. A hit does not evaluate the loader AT ALL, which is asserted with an ETS
counter rather than a local: a local would be captured by the closure and prove
nothing about whether the closure ran.

**`preload` is not built on `@Task`, and cannot be.** On erlang `@Task<T>`
lowers eagerly — decision 120, and `libs/std/src/http.bp` says so in as many
words — so `await` is identity and a task is a value that has already been
computed. `preload`
therefore spawns a monitored child and stores a PENDING marker holding its pid;
a later `memoize` with that key waits on the monitor rather than starting a
second load, and a child that dies without answering is not a poisoned key (the
waiter runs the loader itself). There is no third state in which the frame holds
an unresolved task. Node has no process, so `preload` there runs the loader
immediately and stores the resolved value: the pending row is a BEAM shape, and
every assertion the front makes — the loader runs once, the memo answers the
preloaded value — holds on both rows.

`memoKey(name, parts)` joins with `|` and prefixes the name, and REFUSES a part
carrying the separator — the rule `file_router.bp`'s wire format already applies
to a segment name. A key two different argument lists can produce is a memo that
answers the wrong record, which is the one bug a memo can have. It does not
hash: a request-scoped table is small and a readable key is worth more than a
fixed width.

A loader that raises stores nothing, so the next `memoize` with that key runs it
again.

### The dispatcher contract

This front owns no dispatcher. It owns the contract four of them must honour,
and it is three lines plus a teardown that runs on the failure path too:

```bp
val epoch = beginRequest(RequestScope(
    id: random.uuidV4(),
    phase: RequestPhase.Handler,
    method: "GET",
    path: "/api/posts",
    query: "page=2",
    headersWire: wire,
    strict: false,
));
val body = runHandler();          // wrapped, so a raise still reaches the line below
val setCookies = endRequest();    // the queued `Set-Cookie` lines, `\n`-separated
// … write the response …
val _ = drainAfter(30000);        // reap the deferred work
```

`endRequest()` MUST run on the failure path, or the next request on a keep-alive
connection starts inside the previous one's frame — asserted here by raising a
handler, tearing down, and checking the next request sees a clean frame. The
blob splits on `\n` into whole header values and a value can never split it,
because `serializeCookie` percent-encodes a newline into `%0A` — asserted with a
cookie value carrying a literal `Set-Cookie:` injection.

The phase-to-permission table is written down ONCE, in
`test/request_context_test.bp`'s `permissionRow`, as five literals — `yyyyn`,
`yynyy`, `yyyyn`, `yyyyy`, `yynnn` for headers-read · cookies-read · set-allowed
· after-allowed · marks-dynamic. Fronts 12, 23, 24, 25, 60, 63, 64, 65 and 66
inherit it rather than re-deriving it.

**What this front does NOT ship.** The spec lists two example programs under its
own `examples/` directory, which lives in the meta repository's `specs/` tree
and is not this worktree's to write. The developer's view — a layout auth guard,
a server action writing a cookie and deferring an analytics write, a route
handler reading a header, and one `getPost` shared by `generateMetadata` and the
page — is in `docs.md` instead. `examples/` here is a workspace of buildable
members, and a member exercising a layout or a server action needs fronts 23 and
24, neither of which has landed.

### Language notes this module is written around

- **A `@panic` message must be pure ASCII.** `asserts.throwsWith` catches
  through `io_lib:format("~p:~p", …)`, and `~p` renders a binary holding a
  non-Latin-1 byte as a LIST OF NUMBERS — so a refusal carrying an em dash is
  caught, rendered as `<<114,97,107,…>>`, and matches no needle at all. Every
  refusal text in this module uses `-` where the prose around it uses `—`, and
  the assertions are the reason. Measured, not guessed: the first run of
  `test/request_context_test.bp` on the erlang row failed six cells on it.
- **`i32 / i32` is FLOAT division on commonJS and INTEGER division on erlang.**
  `233 / 16` is `14.5625` on the node row and `14` on the BEAM. Subtract the
  remainder first — `idiv(a, b)` is `(a - a % b) / b` — and the quotient is
  exact on both. Measured while writing `hexByte`.
- **A `from "std"` module imported DIRECTLY by a `test/` file works on both
  rows.** It did not once — the loader the emitted escript runs was only emitted
  when `imported_fns` / `imported_types` / a type module were present, and a
  `from "std"` import fills none of those, so the call was remote into a module
  nobody loaded and every cell answered `{error, undef}`. The compiler closed
  that (with a prelude-defaults guard and an escript loader that no longer skips
  a refused module in silence). Re-measured here on `4fe1747e` with one test file
  per module, each carrying an arithmetic control cell — `querystring`, `time`,
  `unicode`, `crypto` and `base64` are **2/2 green on commonJS and 2/2 green on
  erlang**, all five. So a test file may name a std module itself; nothing in
  this repository has to be routed through a `src/` `pub fn` for loading
  reasons. The two exceptions that are NOT about loading and still hold:
  `std`'s `process` in a test file loses every cell in that FILE on commonJS
  (the run exits 1 and the file contributes no `N passed, M failed` line at
  all), and `std`'s `querystring` is weaker than `ssr.bp`'s own query codec —
  see the note above it.
- **A non-ASCII string LITERAL raises on the erlang row.** `"caf\u00e9".length()`
  is `{badarg, <<...>>}` — before any of this front's code runs. So the positive
  case of the non-ASCII cookie refusal is not expressible as a cell at all; the
  guard, its text and the negative case are asserted instead, and the gap is
  listed here rather than quietly dropped.
- **A refusal is a function.** `noFrameProblem` / `nestedFrameProblem` /
  `staleEpochProblem` are `pub fn`s returning the text, for the reason
  `durationProblem` is one: a test reads the words without the halt taking the
  test down, and every raise site spells the refusal once.

## Externalized configuration

`modules/rakun/src/config.bp` is front 05's half of `#[value("key")]`: front 04
owns the property TABLE (`rkSetProp`/`rkProp`/`rkPropInt`), this module owns what
FILLS it. Two modules, one table, no second store — every source ends in
`rkSetProp`.

**It is botopink, not a sidecar, and that is not a shortcut.** The front's spec
puts the `.json`/`.yaml` decoding in `src/sidecars/rakun_config.erl` because
std's `json` has no structured walker. An erlang-only cell cannot be asserted
from this repository at all: `botopink test` compiles every `test/*.bp` on BOTH
rows with no per-target gate, and a `declare fn` carrying only an
`#[@External.Erlang]` form is a located `has no #[@External.<Target>(…)] for the
node backend` **at the call site**, which reddens the commonJS row — the only row
the core member's `targets` gates. `runtime.mjs` is frozen and a second Node file
is forbidden, so there is no node twin to pair such a cell with. The readers are
therefore written once, in botopink, over std's `fs`/`env` (both carry both
forms), and the same code answers on both rows. `test/config_test.bp` is green on
`commonJS` AND on `erlang`.

### The eight sources, highest precedence first

| # | Source | Form |
|---|---|---|
| 1 | Command-line arguments | `--server.port=9090`, from `env.args()` |
| 2 | `RAKUN_APPLICATION_JSON` | one JSON object in one variable, flattened |
| 3 | OS environment variables | `RAKUN_SERVER_PORT` → `server.port`; `__` → `-` FIRST, then `_` → `.`, lowercased. A variable without the prefix contributes nothing |
| 4 | Profile-specific documents | `application-<profile>.<ext>`, the later ACTIVE profile winning |
| 5 | Base documents | `application.<ext>`, the later LOCATION winning |
| 6 | Configuration trees | `configtree:/etc/config`, one file per key |
| 7 | Programmatic defaults | `rkSetProp` / `boot/1`, already in the table |
| 8 | Declared field defaults | the second argument of a typed reader |

Row 7 is not a layer and needs no enumeration of the table: the merge of rows
6..1 is written OVER the table, so a key nothing else mentions keeps the value
`rkSetProp` gave it and a key a file mentions loses it. Row 8 is not a layer
either — it is the fallback a typed reader applies when the table has no answer.

`rkConfigLoad()` is the entry point and the ONE `-> @Result` seam: a missing
non-optional location, a cyclic import, a refused YAML construct and a
self-referential profile group all come back as one refusal naming the input, so
`main` writes `try rkConfigLoad();` and the boot stops. `rkConfigLoadFrom(args)`
is the same load with an explicit argv, which is what the tests drive (a test
process carries the RUNNER's arguments, never the program's).

The load is TWO passes, because the profile set decides which documents
contribute and a document can set the profile set: pass 1 merges the sources
that carry no condition and resolves the set, pass 2 merges everything with the
set known. Spring does the same for the same reason.

### Locations

`rakun.config.location` is an ordered comma-separated list, defaulting to
`optional:file:./,optional:file:./config/`; `rakun.config.name` (default
`application`) is the document stem. An entry is `[optional:]<file:|configtree:><path>`
and a **file location must end in `/`** — it is a directory, and the stem is
appended to it. A location WITHOUT `optional:` that does not exist is a startup
failure naming the path: the milestone's most-restrictive rule applied to
configuration, where a typo in a location is not a warning. Within one location
the extensions apply low to high as `yml, yaml, json, properties`, so
`.properties` beats `.yaml` for the same key at the same location — Spring's own
rule. `rakun.config.import` pulls in another document at the importing
document's precedence, resolved after it; an import cycle is a startup failure
naming the chain.

### Profiles

`src/profiles.bp` owns the profile SET; front 72 owns every conditional
registration marker that reads it. `rakun.profiles.active=dev,postgres`
activates in order, `rakun.profiles.default` (itself defaulting to `default`)
applies when nothing is active, `rakun.profiles.include[0]` adds
unconditionally, and `rakun.profiles.group.production[0]` expands one name into
a list, transitively, **activating the group name beside its members**; a group
that refers to itself is a refusal naming the cycle.

`profiles.active()` answers the RESOLVED list in activation order — read from
`rakun.profiles.resolved`, which the loader writes. Reading
`rakun.profiles.active` through `#[value]` also works and is a different
question: it is the CONFIGURED string, before `include` and `group` are applied.

A document may carry `rakun.config.activate.on-profile` (the expression grammar
— names, `|`, `&`, `!` and parentheses, `!` binding tightest) and
`rakun.config.activate.on-cloud-platform` (`kubernetes` on
`KUBERNETES_SERVICE_HOST`, `cloud-foundry` on `VCAP_APPLICATION`, `heroku` on
`DYNO`, `azure-app-service` on `WEBSITE_SITE_NAME`, `none` otherwise). Both have
to hold. A document whose conditions do not hold contributes **nothing** — not a
lower-priority value, nothing.

### The document formats

| Format | Covered | Refused |
|---|---|---|
| `.properties` | `key=value`, `key: value`, `#`/`!` comments, `\` continuations, `#---` document separator | — |
| `.json` | the whole grammar, flattened as it is scanned: `{"server":{"port":8080}}` → `server.port`, `{"a":["x"]}` → `a[0]` | a malformed document is a located refusal naming the file |
| `.yaml` / `.yml` | block mappings, block sequences, plain and quoted scalars, `#` comments, `---` document separators | anchors, aliases, flow style, block scalars (`|`, `>`) and tags — each a located error naming the FILE and the LINE, never a silent mis-parse |
| `configtree:` | one file per key, the body is the value, trailing newline stripped | — |

The YAML reader is a documented SUBSET. It covers what an `application.yaml`
actually contains and says plainly what it does not; a full YAML parser is not
this front's work and is not on the critical path. The refusal is the point: a
construct outside the subset stops the boot naming the line rather than loading
a value that is not the one the file says.

### Placeholders, `${random.*}` and the typed readers

`${key}` and `${key:default}` resolve at LOAD time, recursively, over the merged
entries first and the property table second. An unresolvable `${key}` with no
default is a startup failure naming the key and the property that referenced it —
there is no mode in which it silently becomes the empty string — and a cycle
(`a=${b}`, `b=${a}`) is a failure naming the chain.

`${random.*}` is not a source and is not resolved at load time. `rkValue(key)`
resolves it at REFERENCE time, so `${random.int[1024,65536]}` answers differently
per reference and is never cached: `value`, `int`, `long`, `uuid`, `int(10)` and
`int[lo,hi]`. The table keeps the placeholder text, which is what makes the
"differs between two references" property true and is also the one thing
`#[value("key")]` does not see — `decorators.bp` is frozen and emits `rkProp`,
not `rkValue`, so a `${random.*}` key read through `#[value]` answers the
placeholder. Recorded rather than worked around.

| Reader | Answers | Row 8 |
|---|---|---|
| `rkValue(key)` | `string`, with `${random.*}` resolved | `rkValueOr(key, fallback)` |
| `rkPropBool(key, fallback)` | `true`/`yes`/`on`/`1` and their opposites | the argument |
| `rkPropIntOr(key, fallback)` | `i32` | the argument |
| `rkPropFloat(key, fallback)` | `f64` | the argument |
| `rkPropList(key)` | `string[]` from `key[0]`, `key[1]`, … or from a comma-separated scalar | empty |
| `rkPropDuration(key, unit)` | `Duration` | — |
| `rkPropSize(key, unit)` | `DataSize` | — |

**Relaxed binding lives in the reader**, not in the emitter: each tries the
written key, then the kebab-case spelling, then the camelCase one, then the
underscored upper-case one, so `remoteAddress` binds from `remote-address`, from
`remoteAddress` and from `REMOTE_ADDRESS` without the caller knowing which
spelling a file used.

`Duration` parses `30` (against the `#[unit]` default), `30s`, `500ms`, `2m`,
`1h`, `1d`, `PT30S` and `PT1H30M`; `DataSize` parses `10`, `10B`, `10KB`,
`10MB`, `10GB` and `10TB`. An unparsable value is a startup failure naming the
key, the value and the accepted forms — never a zero. The refusal MESSAGE is its
own function (`durationProblem` / `dataSizeProblem` / `boolProblem`) and the
parser asserts on it, which is what lets a test read the message without the
halt taking the test with it.

Both carry `i32` where the spec writes `i64`: an integer literal is `i32` and
there is no widening and no cast, so an `i64` field cannot be given a value at
all. It is not the narrowing it reads as — a botopink integer is a JavaScript
number on the node row and a BEAM integer on the erlang one, so `10GB`
(10737418240) is exact on both and is asserted as such.

### `#[configurationProperties("prefix")]`

A type-level decorator in `src/config.bp` (`decorators.bp` is frozen for the
milestone). It emits three things into the module that declares the record:

```bp
pub fn __rkBind_MyService(prefix: string) -> MyService { … }   // prefix is a PARAMETER
pub fn __rkMake_MyService() -> MyService { … }                 // the ordinary DI factory name
val __rkCat_MyService = rkRegisterConfigKeys("my.service", "…"); // the run-time catalogue
```

The prefix being a parameter is what makes `#[nested]` compose: a nested field
calls the nested type's own binder with `prefix + "." + <field>`, and neither
decorator has to know the other exists. A rakun decorator body cannot call a
sibling function, so composition has to happen in the EMITTED code — which is
also why two levels of nesting work with no extra machinery. `__rkMake_<Name>`
is the ordinary factory name, so a bound record is injectable by type into any
`#[service]` with no further wiring.

The field markers are `#[nested]`, `#[unit("seconds")]` (the unit a BARE number
is read in) and `#[defaultValue("guest")]` (row 8, written where the catalogue
can report it — a default written on the field itself is not visible through
`@Decl.fields`). `#[validated]` marks a record whose constraints run at boot;
front 14 owns the constraints and until it lands the marker is placement only.
`#[enableConfigurationProperties("A,B")]` is the explicit-registration form.

Two deliberate departures from the spec, both arguable and both here:

- **Relaxed binding is in the READER, not the emitter.** The spec rewrites
  `remoteAddress` → `remote-address` in the decorator. `rawValue` does it
  instead, trying the written key, the kebab spelling, the camel spelling and
  the `SCREAMING_SNAKE` one. A decorator body cannot call a helper, so the
  emitter would have to inline the string surgery in every marker; and the
  reader covers three spellings where the emitter would have produced one.
- **A list field is recognised by an EMPTY `typeName`.** `@Decl` renders no name
  for a generic type: `hosts: string[]` reflects as `typeName == ""`, exactly as
  `Array<string>` would. An empty name is read as a list, which is right for
  every array and wrong for any other generic field. It is the only signal the
  reflection offers and it is a gap worth closing in `@Decl` rather than around.

### The key catalogue

A decorator body cannot accumulate comptime state across invocations — each is
lowered alone into its own eval script — so there is no comptime catalogue. The
registry is built at RUN time by the module-load `val`s, and a headless boot
(`rakun.main.headless`, front 04) is what dumps it for `rakun config-catalogue`
(front 88) and the LSP's `application.yaml` completion. It lives in the property
table like everything else: `rakun.config.catalogue` is the comma-separated list
of prefixes and `rakun.config.catalogue.<prefix>` is that prefix's
`name:type:default|…` spec, so there is still one store. `rkConfigLoad`
registers rakun's OWN keys (`rakun.main.*`, `rakun.server.*`, `rakun.config.*`,
`rakun.profiles.*`) beside the application's, so a dump answers "every key rakun
reads".

### Language notes this module is written around

Each was measured against the compiler at `repository/botopink-lang`, not
guessed, and each costs a spelling in `src/config.bp`:

- `String.slice`, `String.chars`, `String.lines`, `String.words` and
  `String.charCodeAt` make the commonJS backend emit a self-recursive
  `String.prototype.charCodeAt` patch that kills the module before a single test
  runs. `String.at` (native `charAt`) does not. Every substring is therefore
  built through `charOf`/`sub`. **Those two live in `config.bp` and nowhere
  else** — `file_router.bp` and `ssr.bp` import them from there. They were
  copied into `file_router.bp` once, byte-identically, under a comment blaming
  the rule that a decorator body cannot call a sibling function; that rule is
  real but does not cover these two, whose call sites in that file are all in
  ordinary functions (the decorator bodies further down carry their own separate
  copies, which is what the rule actually forces). The copies were removed in
  1.0.10-beta when the compiler began refusing an unqualified import that two
  modules both satisfy: `sub` is declared `pub` by `file_router` and by `config`,
  and this import does not say which.
- `Array.pop` is `lists:last/1` on the erlang row — it READS the last element, it
  does not remove it. Nothing here pops; a stack shrinks with `dropLast`.
- `&&` and `||` cannot appear directly inside an `if (…)` or `while (…)` head;
  they need their own parentheses (`if ((a && b))`) or a `val` binding.
- A `val` bound inside a `loop` lambda loses its string type, and `.length()` is
  then emitted as a call against JavaScript's `length` PROPERTY. Every such
  binding is annotated `val x: string = …`.
- A `//` comment inside a braced block is fatal on the node row: the commonJS
  emitter flattens the block onto one line and the comment swallows the closing
  brace.
- On the erlang row `try` unwraps only in a `val` binding — `return try f()` and
  `g(try f())` both hand on the `{ok, …}` wrapper.
- `from` is a keyword and cannot name a parameter.
- `${…}` INTERPOLATES inside a string literal, so a literal `${` has to be built
  (`"$" + "{"`); `"${" + body + "}"` silently compiles to the interpolation of
  `" + body + "` and the value comes out as that text.
- `x.field.length()` is emitted as a call against JavaScript's `length` PROPERTY
  and dies on the node row; bind the field to a local first.
- A `while (cond)` or `for (0..n)` body is lowered to recursion on commonJS, so a
  thousand iterations exceeds the JavaScript stack. std's
  `random.intInRange` also floors a float by walking one recursive step per unit
  of range, which blows the stack for anything the size of a port space — hence
  `randomBelow`, rejection sampling over composed decimal digits.
- A module-level `val` with an ALL-CAPS name is emitted as an erlang VARIABLE and
  comes back `unbound`, which takes the whole module down; every constant here is
  a function.
- The `files` ORDER in a member's `botopink.json` is a dependency order: a module
  has to be listed after every sibling it imports (`http` before `runtime`,
  `profiles` before `config`). It compiles inside the member either way; a
  CONSUMER's build reds with `unbound variable` inside rakun's own source.
- An `if` expression cannot sit on the right of `+` (`i = i + if (…) 2 else 1`),
  and a `var` declared inside a NESTED block of a loop body comes out `unbound`
  on the erlang row — which is why `profiles.matches` is a chain of functions
  over a `Stacks` value rather than one loop with inner loops.

## The container's doors

`modules/rakun/src/context.bp`, `src/events.bp` and `src/lifecycle.bp` are what
makes the IoC container reachable. Before them, constructor injection through an
emitted `__rkMake_<Type>()` was the container's entire public surface: a value
that was not a field of something could not be got at, nothing ran at startup or
shutdown, and nothing reacted to anything.

### The registry holds factories, not names

`rkScan("UserService")` stores a string and nothing can turn a string back into a
constructor, so "resolve by name" cannot be built on top of the scan. The bean
registry stores the FACTORY beside the record, and that one decision is what
makes resolution, eager initialization and the shutdown pass all possible from
the same table.

### `#[managed]` stacks, it does not replace

The six stereotypes (`#[component]`, `#[service]`, `#[repository]`,
`#[controller]`, `#[restController]`, `#[configuration]`) are frozen for the
milestone, and every capability here needs something they do not emit. A rakun
decorator body also cannot call a sibling function, so there is no way to extend
them from outside. So front 06 adds ONE type-level decorator that stacks under an
existing stereotype, exactly the way `#[route]` already stacks under
`#[restController]`:

```bp
#[service]
#[managed]
pub type UserService(repo: UserRepository) { … }
```

`#[managed]` is type-level, so it sees `decl.name`, `decl.annotations` and
`decl.methods` with each method's own annotations — which is everything the bean
registration, the lifecycle hooks and the listener bindings need, emitted in one
pass. When `decorators.bp` unfreezes, this body folds into the six stereotypes
and the extra line goes away. Until then the extra line is the honest price.

### The measurement, not the precedent

Front 05 shipped no sidecar and fronts 22 and 62 shipped both host files, and the
question that decides it is the same one every time: **is the thing being stored
pure?** It was measured here rather than argued by analogy, and the answer is
four values, none of which a string table holds:

| Stored | What it is | Could a `rkSetProp`/`rkProp` string table hold it? |
|---|---|---|
| A bean factory | a closure over a constructor, or over `rkSingleton` and a constructor | no — calling it is the point, and a name is not callable (`list_to_existing_atom("__rkMake_" ++ Name)` yields an ATOM, and an atom is not a function) |
| A `#[postConstruct]`/`#[preDestroy]` hook | a thunk closing over `__rkMake_<Type>()` and a method | no |
| An `#[eventListener]` binding | a closure taking an `Event` | no |
| An `#[exitCode]` generator | a function returning `i32` | no |

So the four tables live in the host on both rows — `src/context.mjs` and
`src/sidecars/rakun_context.erl` — and front 05's three conditions are satisfied
rather than waived:

- **Every cell carries both forms.** `rkBeanStore`, `rkBeanTable`, `rkBeanCount`,
  `rkBeanHasRecord`, `rkBeanInvoke`, `rkBeanTouch`, `rkBeanReset`,
  `rkRequestScoped`, `rkRequestScopeEnd` and the five test-seam cells each
  declare an `@External.Node("./context.mjs", …)` and an
  `@External.Erlang("rakun_context", …)`. Neither row has a call with no binding,
  so neither row reds.
- **`runtime.mjs` is untouched.** The freeze is on a file, not on the idea of a
  node host; `context.mjs` is this front's own.
- **The atom is verified by READING.** `context.bp` emits
  `rakun_context:bean_register(…)`, so `shipErlSidecars` copies
  `src/sidecars/rakun_context.erl` — confirmed at
  `.botopinkbuild/test-out/rakun_context.erl`, never by trusting exit 0. The atom
  is `rakun_context` and never `context`, because rakun emits `rakun/context` and
  a matching sidecar is skipped in SILENCE.

**What the hosts do not know.** The bean record's grammar, the choice between two
candidates, every refusal message, the reverse of the pre-destroy pass and the
boot-event order are botopink, compiled to both targets. The host is handed a
finished line and appends it beside its function; `bean_invoke/1` is an equality
test and a call. Neither host parses a record, compares a qualifier or decides
which of two beans wins — which is what makes "the two rows cannot disagree about
what the container holds" a property rather than a hope.

### The bean record

`path|type|qualifier|scope|primary|lazy|owner`, seven fields:

- `path` is the context the bean was registered into. `""` is the root and
  `ctx.child("request")` is what makes a longer one reachable; a bean is visible
  from a path when it was registered at that path or an ancestor of it, and the
  NEAREST registration wins. That is Spring's parent/child contexts and what
  front 62 builds the per-request scope on.
- `owner` is the declaration the registration came from — the `#[managed]` type,
  the `#[provides]` function, or the `#[configuration]` that `#[imports]`ed it.
  It exists because the ambiguity message has to name both candidates, and a
  registration carries no source location.

**The registration call takes seven scalars, not the spec's five.** The front's
README writes `rkRegisterBean(type, qualifier, primary, lazy, factory)` in its
Mechanism and an ETS row of `{Primary, Lazy, Scope, Factory}` in its step 1 — the
five-argument call has no room for the third of those four, and neither has room
for the owner its own ambiguity message spells (`two beans of type 'Clock'
('systemClock', 'fixedClock')`). Both are added rather than dropped.

### `Context` is injectable, and reached through an annotated local

`context.bp` emits `pub fn __rkMake_Context() -> Context`, which is the name
`decorators.bp` already emits for a field of any type — so a `ctx: Context` field
wires with no extra step. The consumer names that factory in its `import` list
beside `rkScan` and `rkSingleton`, because the emitted wiring calls it at the
APPLICATION site; the front's acceptance says "without any extra declaration",
and an import is not a declaration.

The factory brackets nothing with `rkEnter`/`rkDone` — `Context` is constructed
before the scan runs and depends on nothing, so a component holding one can never
be a cycle through it — and it registers no bean, so `Context` does not appear in
its own `beanNames()` and the eager pass does not build it twice.

**The receiver has to be an annotated local.** `__rkMake_Context().resolve(…)`
and `val ctx = __rkMake_Context();` both lose the optional's payload type (the
`§ Language notes` row about a record method's optional and an unannotated
receiver). Every call site in `test/context_test.bp` writes
`val ctx: Context = __rkMake_Context();`, and that is not style.

### Lifecycle: the markers check placement, `#[managed]` does the wiring

`#[postConstruct]` and `#[preDestroy]` emit NOTHING. A method-level `@Decl`
carries no owner and no parameter list — `Decl` exposes `kind`, `name`,
`returnType` and `annotations`, and `Param` lives only on the `Method` entries of
a TYPE decl — so a method marker cannot name the factory of the type it sits in.
The 1.0.6-beta draft's `rkRegisterLifecycle("<decl.name>", …)` inside a
`#[postConstruct]` body would have registered the METHOD's name as the
component's. `#[managed]` is the only decl that sees both a method and its owner,
so it emits the registrations, exactly as `#[restController]` does for
`#[getMapping]`.

`rkRegisterLifecycle` takes the METHOD as well as the owner, where the front's
README writes `rkRegisterLifecycle(name, "post"/"pre", order, fn)`: its own
step 4 requires a failing hook to be reported "naming the component AND the
method", and four arguments have room for only the first. Nothing in front 06
emits a non-zero `order`; front 72's conditional layer is what will.

`post` runs in registration order (dependency order — a component is registered
after the components it was constructed from) and `pre` in reverse. The post pass
marks an entry DONE, so "exactly once for a singleton, no matter how many sites
resolve it" is a property of the pass and not of the caller. The post pass is not
tolerant: the first raise stops the boot naming the component and the method. The
pre pass is tolerant and logs, because a component that fails to close must not
keep the ones after it open.

### Events: one record, string-named

Spring dispatches by the listener parameter's TYPE. A method-level `@Decl`
carries no parameter list, so an `#[eventListener]` body cannot read
`decl.parameters[0].typeName` — which is exactly what the 1.0.6-beta draft's
step 5 was written around. So there is one `Event(name, source, payload,
timestampMillis)` record and the event is named by a STRING, which is also what
the boundary can carry: a fun in an ETS table handed a record it never inspects.

Dispatch is synchronous and in registration order. A listener that raises is
recorded with its owner and the sequence continues, because a broken audit
listener must not take the boot down; `listenerFailures()` reads them back.

**`Event(name: …, timestampMillis: 0)` — the front's own example — does not
compile.** An integer LITERAL is `i32`, there is no widening and no cast, so an
`i64` field cannot be given a value at all; it is the same gap `config.bp`'s
`Duration` and `DataSize` record. `event(name, source, payload)` is the writable
constructor and stamps `std/io/clock` itself, which is what a publisher wanted
anyway. `std/io/clock` is imported by `events.bp` (a `src/` module) and never by a
test, for the § Language notes reason.

### The boot sequence, and why the failures come back instead of raising

`context.bootSequence()` publishes the eight events in order with the eager pass
between `ApplicationPrepared` and `ApplicationStarted`, and `ApplicationFailed`
REPLACES the tail when the eager pass or a `#[postConstruct]` raises.

That is why `rkBeanTry` and `rkLifecycleRun` hand the failure back as TEXT rather
than raising: the sequence has to publish the failure event before it stops, and
a raise it could not see would skip that. It is also why `postConstructFailure()`
lives in `lifecycle.bp` and not in `context.bp` — describing a failed `Hook` is a
record field read, and it belongs in the module that declares `Hook`.

`main` calls it, not `Rakun.run`: `src/bootstrap.bp` is frozen and cannot grow a
step.

**`AvailabilityChanged` appears twice** in the list and is told apart by its
PAYLOAD (`LivenessCorrect`, `ReadinessAcceptingTraffic`), which is how Spring
tells `LivenessState` from `ReadinessState`. A listener registered per NAME is
therefore registered twice and fires twice per publish;
`test/events_test.bp`'s expected log shows that rather than papering over it.

### Shutdown, the pre-destroy pass and the process status

`lifecycle.shutdown()` runs the pre-destroy pass in reverse registration order
and answers the exit code. **Front 07 calls it after the drain** — it owns the
socket, the readiness flip and the in-flight requests; this front owns the
callback pass and the number. A test calls it directly rather than sending a real
`SIGTERM`, so the run does not take the runner down; the signal path is covered
once, in front 07's graceful-shutdown tests.

`#[exitCode]` is the ONE marker in `lifecycle.bp` that emits: a module-level
function has its own name and its return type, where a method `@Decl` has neither
an owner nor a parameter list. The highest value any generator answers is the
status; with none registered a clean stop is 0, and a FAILED boot never reaches
`shutdown` at all — `bootSequence` halts, and a halt is a non-zero process status
on both hosts without anybody choosing a number.

**There is no `rakun_context:terminate/2`.** The front's README names one, but
this sidecar is not an `application` callback module and is in no supervision
tree — `rakun_file_router`'s shape, for `rakun_file_router`'s reason, since
`shipErlSidecars` ships per atom and the two are shipped independently. A
`terminate/2` nothing calls would be dead code. Front 07 reaches the pass through
the compiled `lifecycle:shutdown/0`, or `rakun_context:lifecycle_run(<<"pre">>,
true)` directly.

`processExitCode()` is deliberately not called `exitCode`: a decorator's
annotation name IS its function name, and `#[exitCode]` is the marker.

### Eager initialization is the deliverable; lazy is already the default

Spring's `spring.main.lazy-initialization` is an opt-in because Spring is EAGER.
rakun is the other way round: `rkSingleton` takes a thunk, so nothing is
constructed until something resolves it and an unresolved component is never
built at all. What this front adds is the EAGERNESS, and
`rakun.main.lazy-initialization=true` turns it off again — the
`#[postConstruct]` pass with it, because a hook runs ON an instance and running
it would construct the very bean the key asked not to construct.

`eagerInit()` walks the ROOT registry only: a child registry is opened per
request and has no boot, so walking the ancestors would build a request-scoped
bean at startup. It skips `#[lazy]` and skips anything that is not a singleton —
a bean built afresh per resolve has no instance to warm.

**"A component whose `#[value]` key is missing fails the boot" cannot happen.**
`rkProp` answers `""` for an absent key and `rkPropInt` answers `0`, by front
04's rule, on both rows, in `runtime.mjs`, which is FROZEN. A missing `#[value]`
key is not an error at boot, at the first request, or ever. What the eager pass
does turn into a boot failure is a construction that RAISES — a cycle through
front 04's guard, or a typed configuration reader that halts — and both are
asserted.

**The cycle diagnostic is worded differently on the two rows.** node raises the
sentence `rakun dependency cycle: component 'X' depends (transitively) on
itself`; the BEAM raises the term `{rakun_cycle, X}`. Both carry the component
name and the word `cycle`, and that is what the assertion is on. A test matching
either sentence would be a one-row test.

### Scopes, and the refusal reflection can actually reach

`Singleton` registers `{ -> __rkMake_<Type>() }`, the stereotype's cached
factory, and that is what constructor injection always gets. `Prototype` and
`Request` register a FRESH constructor `__rkNew_<Type>()` that `#[managed]` emits
itself, with the same per-field injection rule the stereotypes use; `Request`
wraps it in `rkRequestScoped`, which is `rkSingleton` one scope down — the
process dictionary on the BEAM, so two concurrent requests are two processes and
never share, and an explicit bracket on node, which is single-threaded.

The front's step 6 asks for "`#[scope("request")]` on a type whose factory is
constructor-injected somewhere fails at comptime naming the injection site's
limitation". **No decorator can see another type's fields**, so that check is not
writable. What IS writable is its REASON: the stereotype is what emits the
singleton `__rkMake_<Type>()` a field resolves through, so `#[managed]` refuses a
non-singleton scope on a type that also carries a stereotype. Without one there
is no `__rkMake_<Type>` at all, and a field of that type fails the build at its
own injection site with `unbound variable`. Same guarantee, reached from the half
reflection can see.

`#[managed]` also refuses `#[postConstruct]`/`#[preDestroy]` on a non-singleton
bean: both passes run once, over an instance nobody kept.

**A non-singleton `#[managed]` type carries its own `rkScan`**, because no
stereotype scanned it. Its module therefore imports `rkScan` and, for a request
bean, `rkRequestScoped`.

**`rkBuildCount` does not count a prototype.** It counts what `rkEnter`/`rkDone`
bracket, and `__rkNew_<Type>` is deliberately unbracketed — a fresh construction
per resolve is not a cycle. A prototype test observes the constructor through its
own counter instead.

### A module that imports `Context` must also import `Event`

`Context.publish(self, ev: Event)` puts `Event` in the record's method signature,
and the type has to resolve at the USE site: a module importing `Context` and not
`Event` is `unknown type 'Event'`, reported at an unrelated line. Every consumer
of `Context` imports both.

### `#[imports]`, and the scan root that needs no analogue

`#[imports("DatabaseConfig,SecurityConfig")]` on a `#[configuration]` type
registers a bean for each named type, so a configuration record in a module the
application does not otherwise reference is still wired. This is Spring's
`@Import`. Each named type must already have a `__rkMake_<Type>()` — from a
stereotype, a `#[configuration]`'s `#[bean]`, or a `#[provides]` — and a name
with none is `unbound variable '__rkMake_<Name>'` at the import site, which names
both the type and the configuration that asked for it.

Spring's `@ComponentScan(basePackages=…)` has NO analogue here and needs none: an
additional scan root in botopink is a `pub mod` line, because module resolution
is already explicit. The front says that rather than inventing a `basePackages`.

### What front 23 consumes from this front

Front 23 (the SSR pipeline) and everything behind it waits on this front. This is
the surface it may rely on; none of it changes without a note here.

| What | Where | Shape |
|---|---|---|
| The root context | `context.__rkMake_Context()` | `Context`, a singleton, exempt from the cycle guard and absent from its own `beanNames()` |
| Per-render resolution | `ctx.resolve(typeName)` / `ctx.resolveNamed(typeName, qualifier)` | `?T` from an ANNOTATED binding — `val x: ?Foo = ctx.resolve("Foo")`; the string is unchecked against `T` |
| The per-request child | `ctx.child(name)` → `rkRegisterBeanAt(path, …)` | a bean is visible from a path when registered at it or an ancestor, nearest wins; `""` is the root |
| Request scope | `rkRequestScoped(key, build)` · `rkRequestScopeEnd()` | the process dictionary on the BEAM, an explicit bracket on node. Front 62 owns the ACCESSORS; this is the storage |
| Publishing | `ctx.publish(ev)` · `events.publishEvent(ev)` · `events.event(name, source, payload)` | answers how many listeners ran; a listener that raises is recorded, not propagated |
| The boot | `context.bootSequence()` from `main` | 8 on a clean boot; publishes `ApplicationFailed` and halts on a failed one |
| Shutdown | `lifecycle.shutdown()` | front 07 calls it AFTER the drain; answers the process status |
| The bean list | `context.rkBeanNames()` / `ctx.beanNames()` | registration order, one entry per type — front 11's `beans` endpoint |

The three wire records are stable and are the only thing either host sees:

```text
bean      path|type|qualifier|scope|primary|lazy|owner     ("" path = root, 1/0 flags)
hook      owner|method|phase|order                         (phase is "post" or "pre")
listener  event|owner
```

`events.bootEventNames()` and `events.bootEventPayloads()` are the eight boot
events, index-aligned; `events.applicationFailedEvent()` is the ninth name.
Neither list is a literal anywhere else, so a front that wants to observe the
boot reads them rather than spelling them.

### A type NAME is node-global on the erlang row

`botopink test` runs each test FILE in its own process on the node row and in ONE
node on the erlang row, where `rkSingleton`'s cache is a node-global ETS table
keyed by the type name. So two test files declaring a type of the same name are a
real collision there: the second `__rkMake_Clock()` finds the first file's
instance in the cache and hands it back, and the caller's method call on a
foreign record is `{error, undef}`.

Measured while writing front 06 step 3: `overlapping_routes_test.bp` and
`scopes_test.bp` each already declare a `Clock`, a third one in
`test/context_test.bp` turned both of their cells red, and the node row showed
nothing. Every type a test file declares is named for that file
(`ZoneClock`, `OrderCache`, `WarmCache`), and that is not style.

### Resolution and the tie

`__rkMake_<FieldType>()` is unique by construction, so constructor injection
cannot be ambiguous; a tie is only reachable through the registry, from two
`#[provides]` functions or two `#[bean]` methods producing one type. So
`rkResolve(typeName)` takes the single candidate, or the single `#[primary]` one,
and otherwise RAISES naming both owners. A tie is an error and never a silent
first-wins. `rkHasBean` never raises — an ambiguous type IS registered, and a
caller asking whether the container knows about it deserves the answer rather
than the halt `resolve` owes it.

`resolve` takes the type name as a STRING because the type argument is not
reachable at run time: there is no `@typeName<T>()` and explicit generic
arguments do not parse at a call site. The type comes from the annotated binding
— `val repo: ?UserRepository = ctx.resolve("UserRepository");` — and the pairing
of `T` with the string is unchecked. Both halves are language gaps, recorded in
the front's README; dropping the generic and returning `any` would lose the type
everywhere, and the string is the smaller cost.

## The SSR pipeline

`modules/rakun-app/src/ssr.bp` is where a URL becomes bytes. Front 22 finds the
page and the layout chain, front 62 opens the request scope, front 06 resolves
what the render asks the container for — and this file composes, escapes,
renders, wraps the result in a document, writes the payload the browser
reconnects through, and hands front 04's transport an ordered list of chunks.

### `Element` is generic here, and that is not a style choice

`Element` is jhonstart's type. rakun declares no dependency on jhonstart and
must not learn one — the rule that already made every signature in
`file_router.bp` generic in `El`. A walker, though, has to be able to ask a tree
six questions, so the questions arrive as a record of function values:

```bp
pub type ElementView<El>(
    make: fn(string, string, Array<#(string, string)>, El[]) -> El,
    tagOf: fn(El) -> string,
    valueOf: fn(El) -> string,
    attrsOf: fn(El) -> Array<#(string, string)>,
    childrenOf: fn(El) -> El[],
    isVoid: fn(string) -> bool,
    isRawText: fn(string) -> bool,
)
```

`isVoid` and `isRawText` are front 94's `isVoidTag` / `isRawTextTag`, **passed
in**. That is the point: the front's own text says the void set is not restated
here, because two lists that must agree will not agree for long and the second
one is always the stale one. `grep` this module for a tag name and there is one
— `"div"`, the element a template wrapper and an island marker are — and no set
of any kind. The same seam shape as `RenderHooks`, one type-level out.

`make` takes the four parts in one order — tag, value, attrs, children — where
jhonstart's `Element` spells them in another. An adapter that maps them is one
line in the library that owns the element type; front 26 writes it, this front
never sees it.

`Node` + `nodeView(isVoid, isRawText)` is rakun's own element, for a rakun
application that ships no UI library and for this front's own assertions. It is
not a second `Element`: nothing in the pipeline mentions it, and its two
predicates are still parameters.

### Two call-site rules, both erlang-only, both measured here

- **A function-valued record FIELD must be read into a local before it is
  called.** `v.tagOf(e)` lowers to a METHOD call — `tagOf(V, E)` — and the
  erlang row reds with `function tagOf/2 undefined`; the commonJS row is
  perfectly happy, which is what makes it worth writing down. `val tagOf =
  v.tagOf; tagOf(e)` is the same value and lowers on both rows. Every call
  through `ElementView` and `RenderHooks` in this module and in its consumers is
  written that way.
- **A named function used as a value does not lower on erlang.** Build a view or
  a hooks record with `{ t -> isVoidTag(t) }`, never `isVoidTag`. Front 22
  measured it for the four markers; it applies to every field of both records.

Two more the front hit and worked around rather than reported second-hand:

- **`xs.at(i).unwrapOr(…)` reads the element back UNWRAPPED inside a function
  generic in `El`.** `compose` died with `{case_clause, {file_router__t__routeentry, …}}`
  on the erlang row — the record itself in the clause, not an optional around
  it. The same expression in `file_router.bp`, in a non-generic function, is
  correct. `compose` walks `chain.reverse()` with a `loop` binder instead, which
  is the shape the front's own gap table already prefers.
- **A local `val` may shadow a module-level `pub fn` of the same name for an
  IMPORTER.** `renderIn` bound `val raw = isRawText(tag);` beside the module's
  `pub fn raw(v, html) -> El`, and a test file importing `raw` was told
  `expected Node, got bool` — the local's type, reaching a consumer. The local is
  `rawBody` now. Two minutes, if the error had not been read in the right file.

### Step 1 — the rendered page

`http.bp` is frozen and `Response(status, body)` carries no header list and no
streaming body, so the pipeline answers with a record of its own:

```bp
pub type RenderedPage(status: i32, headers: Array<#(string, string)>, chunks: string[])
pub fn renderedPage(status: i32, chunks: string[]) -> RenderedPage
pub fn toResponse(page: RenderedPage) -> Response
```

`Content-Type: text/html; charset=utf-8` is on every `RenderedPage` this front
produces — `htmlHeaders()` is not a parameter — and `toResponse` is the ONLY
place the chunks are joined, which is exactly what the streaming path refuses to
do. When `http.bp` unfreezes, `RenderedPage` collapses into `Response` and
`toResponse` disappears.

### Step 2 — composition order is a function, and it is tested

```bp
pub fn compose<El>(v: ElementView<El>, chain: RouteEntry[], route: PageContext,
                   nav: i32, page: El) -> El
```

For each segment, root-first, the page is wrapped from the inside out: `page`,
then `N` not-found, `S` loading, `E` error, `T` template, `L` layout. So the
outermost element is the root layout and the nesting reads
`layout > template > error > loading > not-found > page`, asserted on the markup
string rather than in prose. A convention nobody registered contributes NO
wrapper — the nesting shrinks, it does not gain an empty `div`.

The chain is front 22's: `matchPath(…)`'s `chain` field is ALREADY the root-first
`L` list, so a caller holding a match never calls `layoutChain` a second time.

A `T` wrapper is the one place this front adds an element of its own: a `div`
carrying `data-onze-t="<pattern>#<nav>"`, the key that makes a template re-mount
on the client while the layout around it does not. Two renders of one route
carry two different keys, because `nav` is a counter and not a hash of the
route.

**`selected`, the layout depth, is a slot and not a field.** Front 26's router
state maps one-to-one onto the payload's `p`/`m`/`q`/`r` with one exception —
`selected` is per-layout rather than per-document. `LayoutProps(route, children,
slots)` is front 22's record and carries three fields; widening it would touch a
file this front does not own, and a fourth positional argument is not
expressible while a declared parameter default is never applied. So the pipeline
writes the depth before each layout render and a layout reads it back with
`selected()` — root layout `0`, the next one down `1`. A three-deep chain yields
`0, 1, 2`, asserted by a layout that renders its own depth as its tag.

**`registerBoundary(kind, pattern, render)`** puts an `S`, an `E` or an `N`
record in front 22's table with its render beside it, through front 22's own
public cell. Fronts 30 and 31 own those MARKERS; until they land this is how a
boundary gets registered, and nothing here writes a wire record by hand.

### Step 3 — escaping is the render, not a step before it

`renderNode(v, e)` is a full re-implementation of the walk in
`jhonstart/element.bp`, and it is what every path in this front calls. The four
differences:

| Node | the frozen `renderToString` | `renderNode` here |
|---|---|---|
| `#text` | `e.value` verbatim | `escapeHtml(e.value)` |
| `#text` inside a raw-text tag | verbatim | verbatim, and `</script` / `</style` is **refused** |
| attribute | `name="value"` verbatim | `name="` + `escapeAttribute(value)` + `"` |
| a void tag | `<input></input>` | `<input …>`, no closing tag |
| `#raw` | renders `<#raw>` | `e.value` verbatim — the single documented escape hatch |

`escapeHtml` covers `&`, `<`, `>`; `escapeAttribute` adds `"` and `'`. The `&`
is replaced FIRST or the ampersand of an entity is escaped a second time.

**Front 01's `escape.html` / `escape.attribute` do not exist on this binary** —
`libs/std` has no `escape` module — so the two functions are here, in pure
botopink, spelled as front 01 specifies them. When front 01 lands they are two
bodies to delete, not to reconcile.

**A raw-text body is verbatim, and the one sequence that closes it early is
refused rather than escaped.** `escapeHtml` applied to a CSS body turns `a > b`
into `a &gt; b` and applied to a script body turns working code into text, so
escaping a `script` or `style` body would silently change the program. Emitting
it verbatim is only safe because a body containing `</script` or `</style` — in
any case, matching the HTML parser's own rule — FAILS the render with the tag
named. Refusing is the restrictive answer and there is no flag that turns it
into escaping.

**No path in `ssr.bp` calls `renderToString`**, and it could not: jhonstart is
not importable from here. The frozen renderer still writes `</input>` and still
escapes nothing, so any assertion about escaped output or a missing closing tag
holds through `renderNode` ONLY. A test that renders a form with
`renderToString` is testing the wrong function.

### Why this front ships BOTH host files

Front 05's three measurements hold and none is violated: every cell carries an
`@External.Node` and an `@External.Erlang` form, so neither row has a call with
no binding; `runtime.mjs` is frozen but `ssr.mjs` is this front's own file; and
the atom `rakun_ssr` is named in emitted output — twenty-two call sites in
`.botopinkbuild/test-out/ssr.erl` — so `shipErlSidecars` copies
`src/sidecars/rakun_ssr.erl`, **verified by reading**
`.botopinkbuild/test-out/rakun_ssr.erl` and diffing it against the source, not
by trusting exit 0.

What decides the shape is front 22's question, and it is the same answer fronts
22, 62 and 06 gave: **is the thing being stored pure?** Front 05's config
readers were, and a sidecar would have been a second copy of something botopink
can do. These are not. The host holds a record of seven FUNCTIONS (the installed
`RenderHooks`), a gather over unstarted THUNKS, and two per-render ordinals that
must survive a call into user code. No string table holds a closure. The
escaping, the walker, the composition order, the payload format, the document
shell and the chunk protocol are botopink, compiled to both targets; neither
host knows what HTML is.

The module atom may not be `ssr`: rakun emits `rakun/ssr`, and `shipErlSidecars`
skips a qualifier matching a module this build emitted — silently. Every rakun
sidecar is `rakun_<name>.erl`.

## The auto-configuration pass

`modules/rakun/src/autoconfig.bp`, `conditions.bp`, `condition_report.bp` and
`autoconfig_registry.bp` are front 72: conditional registration, ordered, with a
report of every decision.

**Why it exists.** Every stereotype in `decorators.bp` is unconditional — a type
carrying one is registered, always, in every application, on every profile. That
is what makes a framework module impossible to ship: `rakun-data` wanting to
provide a default `DataSource` can either mark it `#[component]` and build it in
every application that pulls the module in, including the ones that already
declare their own and the ones that have no database, or not mark it and have
every application write the wiring by hand. "Add the module, it configures
itself" is the promise that separates Spring Boot from Spring.

### The surface

| Marker | Sits on | Record |
|---|---|---|
| `#[autoConfiguration]` | a record-shaped `type` | — (it reads the rest) |
| `#[conditionalOnModule(name)]` | type or `#[bean]` method | `M\|<name>` |
| `#[conditionalOnProperty(key, having)]` | type or `#[bean]` method | `P\|<key>\|<having>` |
| `#[conditionalOnBean(typeName)]` | type or `#[bean]` method | `B\|<typeName>` |
| `#[conditionalOnMissingBean(typeName)]` | type or `#[bean]` method | `X\|<typeName>` |
| `#[profile(name)]` | type or `#[bean]` method | `F\|<name>` |
| `#[autoConfigureBefore(name)]` / `#[autoConfigureAfter(name)]` | an `#[autoConfiguration]` type | the two order lists |

Records are joined with `;`, fields with `|`; neither may appear in a module
name, a property key or value, a type name or a profile name, and every marker
refuses one at COMPTIME rather than emitting a blob that cannot be parsed back.
Conditions are conjunctive and there is no `anyOf`, no expression language and
no escape hatch: a configuration that needs a disjunction splits into two, which
is also the form that reads correctly in the report.

The application calls `autoConfigure()` — or `autoConfigureExcept(names)` — once,
before `Rakun.run`, reads `isAutoConfigured(name)` and prints or serves
`autoConfigurationReport()` (`rkAutoReport()` under its seam name, which is what
front 11 hands back at `/actuator/conditions`).

### Where the pass is called from, and why that is a narrowing

`bootstrap.bp` is frozen for the milestone, so `Rakun.run` cannot run the pass.
The application writes the line:

```bp
val _ = autoConfigure();
Rakun.run(App(port: 8080, basePath: "/api"));
```

The alternative — applying lazily on the first `rkAutoMatched` read — would make
the result depend on which component happened to be resolved first, which is
exactly the ordering bug the sort exists to prevent. Until `bootstrap.bp`
unfreezes the line is explicit, and the report says plainly when it was never
called instead of printing an empty table.

### Sort first, then evaluate

`rkAutoApply/1` builds the edge set, topologically sorts it and only then walks
the sorted list evaluating conditions. Three sources of edges: `after` is
`B -> A`, `before` is `A -> B`, and a `#[bean]` method is always after the
configuration that owns it. An ordering annotation names a CONFIGURATION and a
configuration's beans belong to it, so each named configuration expands to
itself plus every entry it owns — otherwise "after `RakunCoreAutoConfiguration`"
would put `A` before that configuration's beans and `#[conditionalOnMissingBean]`
would see the owner applied and the bean it provides still missing. The walk is
Kahn's with ties broken by REGISTRATION order, so the report is stable across
runs. An edge naming an unregistered configuration is dropped, not refused
(Spring's `@AutoConfigureAfter` routinely names a class that is not present); a
cycle is a startup failure naming its members.

`test/autoconfig_test.bp` asserts the ORDERED answer twice — once through real
annotations, once through a synthetic pair registered in the wrong order with
and without the `after` — so deleting the sort reds ten cells rather than one.

### What an entry PROVIDES is a cell, not a record letter

A `#[bean]` method emits a factory; it does not call `rkScan` and does not
register a bean, so an applied configuration would be invisible to a later one
asking whether anybody had already supplied a `MailSender`. Each entry therefore
also declares what it contributes, through `rkAutoProvides(name, typeName)` — a
configuration provides itself, a `#[bean]` method its return type — and the apply
pass adds it to the registered set the moment the entry matches. It is a
separate cell and not a sixth record letter because `rkAutoConditions(name)` has
to answer the blob the annotations produced, VERBATIM, or it stops being the
comptime half's assertion point.

`B|`/`X|` are then answered by three sources at once: front 04's
`rkScannedNames()`, front 06's `rkBeanNames()` and the provides of the entries
applied so far in this pass.

### The gate, and the one thing it cannot reach

A bean factory of an unmatched configuration RAISES when called, naming the
configuration and the condition that failed; it does not return a half-built
value, and a pass that never ran is its own refusal, because "nothing matched"
and "nobody asked" are different answers.

`#[autoConfiguration]` emits its own `#[bean]` factories, so the gate goes
inside them. `#[profile]` on an ordinary `#[service]` cannot do that:
`decorators.bp` is frozen and its stereotypes emit `__rkMake_<Type>()`
unconditionally. **The narrowing:** the marker leaves the component UNBUILT — the
factory is lazy, nothing calls it at module load and `rkBuildCount` stays 0 — and
emits `__rkAutoGated_<Type>()` beside it, which raises with the diagnosis instead
of building. When `decorators.bp` unfreezes the gate moves into the factory and
the accessor goes away. The alternative would have been a second
`pub fn __rkMake_<Type>` definition, which is a duplicate the node row accepts
silently (front 06 § `#[provides]` measured the same thing).

### Exclusion: two channels, one resolution path

`rakun.autoconfigure.exclude` (read through front 05's table, comma-separated or
indexed) and `autoConfigureExcept(names)` union into `rkAutoApply/1`'s single
argument; the report recovers the channel by re-reading the property. An excluded
name that matches no registered configuration is a startup FAILURE listing the
registered names, not a warning: a typo in an exclusion disables nothing and
leaves the developer believing they turned something off. An excluded entry's
conditions are not evaluated at all.

### The report

Three blocks — applied, not applied, excluded — walked in the SORTED order, each
failed row naming the first failing record AND the value observed. "did not
match: `P|rakun.mail.host|*`" is a restatement of the source; "did not match:
`P|rakun.mail.host|*` - the property is empty" is a diagnosis. Only the first
failing condition is reported, because evaluation short-circuits there and
claiming anything about the rest would be a guess. `rakun.main.debug=true` prints
it at boot; `false` prints nothing and `rkAutoReport()` still answers the full
table — the switch is over the printing, never over the data.

### Why the host is a table and nothing else

Front 06's measurement decides the split, applied rather than cited: is the thing
being stored a FUN? It stores a bean factory, a lifecycle thunk, a listener
closure and an exit-code generator, no string table holds a fun, so its grammar
stayed in botopink and only its table crossed. Here NOTHING is a fun — four
strings per registration and one decision per name — so the host is an
append-only table and nothing more. The blob grammar, the sort, the evaluator,
every refusal text and the rendered report are botopink, compiled twice. A front
that needs a new KIND of condition adds a record letter and a branch in
`conditions.bp`'s `evaluateRecord`; it does not add a second registry and it does
not write the branch twice in two host languages.

The `#[conditionalOnModule]` manifest read is botopink for the same reason: it is
`std`'s `fs.readText` plus a scanner over `botopink.json`'s `dependencies`, which
normalises BOTH on-disk shapes (`["rakun"]` and `{"rakun": {…}}`) exactly as
`compiler-cli/src/cli/config.zig` does, with fixtures under
`test/fixtures/autoconfig/` asserting each. A manifest that cannot be read is a
REFUSAL, not a `false`: "this module is not a dependency" and "I could not find
out" are different answers, and a condition that silently takes the second for
the first turns every `#[conditionalOnModule]` in the build off without saying so.

The module atom may not be `autoconfig`: rakun emits `rakun/autoconfig`, and
`shipErlSidecars` skips a qualifier matching a module this build emitted —
silently. Every rakun sidecar is `rakun_<name>.erl`.

### Why this front ships BOTH host files where its spec said erlang only

The spec (`specs/1.0.10-beta/03-rakun/72-rakun-auto-configuration/README.md`
§ Test plan) declares the host cells `@External.Erlang`-only and says "the tests
are declared erlang-only and the lib test runner is told so". Measured against
the pinned compiler: **there is no per-file target gate.** `botopink test`
compiles every `test/*.bp` on BOTH rows with no per-target switch
(`compiler-cli/src/cli/test_cmd.zig`), and the only target whitelist is per-LIB —
`botopink.json`'s `targets`, read by `lib-test-runner/src/discovery.zig`. rakun
core declares `targets: ["commonJS"]`, so an erlang-only test file would (a) red
the commonJS row at the first call to a cell with no node form and (b) never run
in the gate at all, which runs only the commonJS cell. Both halves are shipped,
which is front 06's precedent and its reason: every cell carries both forms, so
neither row has a call with no binding.

### Language notes this module is written around

Everything here is measured against the pinned compiler, smallest program, both
rows.

- **`from` is a reserved word and may not name a field or a parameter.**
  `pub type Edge(from: string, to: string)` is `error[field-needs-name]: a field
  with no name`, and `fn openerAfter(s: string, from: i32)` is `this token cannot
  appear here — unexpected \`from\``. The edge record spells its ends `earlier`
  and `later`.
- **`println`/`print` have no erlang lowering, and the failure lands nowhere near
  the cause.** `libs/std/src/builtins.d.bp:12-16` declares both; the commonJS row
  runs them, and the erlang row emits a bare local call. The smallest program is
  one module with `pub fn tag() -> string { return "sink"; }` beside
  `pub fn shout(line: string) -> i32 { println(line); return 1; }` and one test
  calling `tag()`: commonJS `1 passed, 0 failed`, erlang
  `FAIL ({error,undef}) at sink_test.bp:3`. `erlc` refuses the module with
  `function println/1 undefined`, the test runner's `__bp_load_siblings/0`
  compiles every `.erl` beside the script and SKIPS a failure silently
  (`codegen/erlang.zig`, the loader's `_ -> ok`), so the whole module is absent
  and every function in it answers `undef` — pointing at the caller, never at the
  print. Until it is closed the report prints through `rkAutoPrint`, a cell of
  this front's own with both forms.
- **`a.args` carries the SOURCE TEXT of a decorator argument, quotes included,
  and `decl.annotations` includes the marker's own annotation.** Measured with a
  throwaway marker: a type carrying `#[probe] #[probeArg("rakun.mail.host", "*")]
  #[probeMark]` reflects `probe,probeArg,probeMark` and args
  `["rakun.mail.host"~"*"]`. So a literal is unwrapped with
  `.split("\"").join("")`, an argument is read with `.slice(i, i + 1).join("")`
  (`.at(i)` returns `?T` and is undefined in the eval script), and the "two
  `#[profile]` markers on one type" check counts every `profile` on the
  declaration.
- **`@emit("")` emits nothing**, which is what makes a conditional contribution
  expressible without a dummy line in the `else` branch. `#[managed]` relies on
  the same.
- **A nested closure may write a `var` of the enclosing decorator body**, two
  levels deep — the method walk accumulates a separator violation from inside
  `m.annotations.forEach` into the body's own `bad`.

### What front 11 consumes from this front

`rkAutoReport()` — verbatim — for `/actuator/conditions`, plus
`reportStateOf(name)` / `reportReasonOf(name)` / `reportNames()` when it wants
the same decision as structured members rather than as a block. There is one
producer; a second renderer would be a second answer.
## The filter chain — `modules/rakun-web/`

`modules/rakun-web/` is the member front 07 fills, and it is the first member
besides the core with real code and its own tests. One ordered chain sits
between the socket and the route handler; everything cross-cutting in track B
enters through it and through nothing else.

**Measured 2026-09-21 against compiler `2e6bb4ac`, with front 07 AND front 72 in
the tree:** `botopink test` (the member's own target, erlang) is **83/83** and
`botopink test --target commonJS` is **83/83**. `modules/rakun` is untouched by
this front and reads what front 72 left — 346/346 on commonJS, 344 passing / 2
failing on erlang, the two still front 04's `server_test.bp:74,80`. (Front 07
was written against the pre-72 core, where the same two cells were the only
reds at 302/300; neither count is this front's and neither moved because of
it.) Before this front the member had no `test/` directory at all, so
`botopink-lang/scripts/restricted-targets.txt`'s line
`rakun-web commonJS 0 03-rakun/F07` keeps its pinned `0` and loses its reason:
"no tests yet" is now "83 tests, all green".

### Why there is ONE chain and two entry points

The 1.0.6 draft asked for Spring filters; the 1.0.7 draft asked for a Next-style
`middleware.bp`. Two pipelines would mean two orderings, a CORS header set in one
and overwritten in the other, and no answer to "does my filter run before the
middleware". So `#[filter]` and `#[middleware]` are two REGISTRATIONS into one
list, at two default orders.

| Entry point | Registers as | Default order | Suits |
|---|---|---|---|
| `#[filter]` on a component | one entry per component, ordered by `#[order("N")]` | `0` | reusable concerns: CORS, compression, metrics, security |
| `#[middleware]` on a `pub fn` in `middleware.bp` | exactly one entry | `−50` | the application's own request gate: auth redirects, rewrites, locale |

`test/middleware_test.bp` writes the same redirect both ways in one cell and
asserts the two responses agree field for field, which is the honest way to make
the claim checkable.

### The order band

Negative is early, positive is late. `orderBand()` is the whole table as one
string, so a test asserts it as a WHOLE rather than row by row.

| Order | Entry | Owner |
|---|---|---|
| −400 | request id | 07 (ships) |
| −300 | security | 10 |
| −250 | URL rules: redirects, rewrites, `basePath` | 65 |
| −200 | CORS | 07 (ships) |
| −150 | API version resolution | 07 (not reached) |
| −100 | problem-detail / error boundary | 07 (ships) |
| −50 | `middleware.bp` | 07 (ships) |
| 0 | application filters, default | the application |
| +100 | metrics and tracing | 11 |
| +200 | compression | 07 (not reached) |
| +300 | server identification | 07 (not reached) |

Compression is late on purpose: it must see the final body, including one an
error handler produced.

### Where it hooks in, and the one thing that is untestable from `.bp`

Front 04's `dispatch_http/5` calls `rakun_chain:run/6` when the module is loaded
and the handler directly when it is not. `run/6` looks for a RUNNER — botopink's
`runChain/5`, handed over by `bootWeb()` — and falls back to calling the handler
itself when none is registered, so a build carrying rakun-web but never booting
its web layer behaves exactly as front 04 does. **Neither branch is reachable
from a `.bp` cell**: `run/6` needs a socket and a live route table, and the
suite has neither. What the cells drive is `runChain/5` directly, which is the
same function `run/6` calls. The seam itself is covered by reading the two
modules, not by a test, and this paragraph is the record of that.

### The chain's request value is NOT `Request`, and why

rakun's `Request` is a host-supplied `behavior`, and a method on one does not
dispatch on the erlang row: `req.header("origin")` lowers to a map field read of
`header` followed by a call. That is the defect keeping `test/server_test.bp:74`
and `:80` red in the core (`{badkey,param}` / `{badfun, #{…}}`), and a chain
that cannot read a header cannot do CORS. So the chain carries its own RECORD,
`WebRequest(method, path, target, headersWire, queryWire, body)`, built from the
same scalars the dispatcher already has, with `header`/`hasHeader`/`names`/
`query` methods that read through front 62's wire grammar
(`headerLookup`/`headerNames`/`headerPresent`, imported, not re-spelled). Record
methods dispatch on both rows. The spec writes `Filter.handle(self, req:
Request, chain: Chain)`; the deviation is one type name and it is here because
the spec's spelling does not run.

`path` is what the client asked for and never changes. `target` is what the
route table is asked about, and `Next.rewrite` is the only thing that moves it —
so a rewrite is invisible to the client and visible to the router.

### The status-0 sentinel

`Response` is frozen at `(status, body)` with no header builder, so a
middleware's "continue" and "rewrite" cannot be ordinary responses. Zero is not a
valid HTTP status, so `Next.pass()` and `Next.rewrite(p)` answer
`Response(status: 0, body: "")`; `chainNext` reads it as "continue to the next
entry" and consumes the `rewrite` signal on the way. A sentinel that walks off
the END of the chain becomes a 404 rather than reaching the wire — asserted, not
assumed.

### `withHeader`, and replace-by-name

`Response` has no header field, so `withHeader(res, name, value)` writes through
a per-request accumulator and returns the SAME `Response`. Name matching is
case-insensitive (RFC 9110 §5.1) and **the semantics are replace-by-name**, with
exactly two exceptions:

- **`Set-Cookie`** is a boot-time REFUSAL naming front 62's list API. A replace
  would set one cookie and drop the rest. `writeCookies(blob)` takes
  `endRequest()`'s `\n`-separated lines and writes one `Set-Cookie:` per
  element; `responseHead()` is the only place the two accumulators meet.
- **`Vary`** is unioned over the comma-separated token set, case-insensitively,
  first spelling kept — the CORS entry adds `Origin`, a future compression entry
  adds `Accept-Encoding`, and both must survive.

`withHeaders(res, pairs)` takes the spec's `#(string, string)[]` — MEASURED, not
assumed: a tuple-array parameter, an array literal of `#("X-A", "1")` pairs at
the call site, and `.0` / `.1` field reads all compile and answer on BOTH rows
against `2e6bb4ac`. It started as a flat `["name", "value", …]` array with an
odd length refused, and the pair type is strictly better because it makes "a
name with no value" unrepresentable rather than refusable. Same replace rule
between its own entries.

**The BEAM half mirrors every write into `rakun_runtime:set_reply_header/2`** so
the line reaches the socket, guarded by `function_exported/3`. The node half does
not: `runtime.mjs` is frozen, carries no `setReplyHeader`, and this front does
not unfreeze it — so on the node row the accumulator is rakun-web's alone and the
node server writes no reply header, exactly as before front 07.

### CORS: the three restrictive defaults

1. **No origin is allowed until one is named.** `denyAll()` is the policy with no
   policy, and `Access-Control-Allow-Origin` is never set from it.
2. **The wildcard with credentials fails at BOOT**, naming the combination, and
   there is no property that downgrades it. Either half alone is legal.
3. **A preflight for a path with no route answers 404**, not a permissive 204 —
   `routeExists` reads front 04's `rkRoutePaths()` and matches `:name` segments.

`Access-Control-Allow-Origin` ECHOES the request origin and never answers `*` for
an allowed one, and `Vary: Origin` is set on **every** response the policy looked
at, allowed or not. A preflight from a disallowed origin, or for a method the
policy does not allow, answers **403** rather than a bare 204: 204 with no
allow-origin reads to a browser exactly like a misconfiguration, and 403 says
which side said no. The spec does not pin that case; this is the restrictive
reading and it is written down here rather than left to the code.

The global policy is a `#[provides]`d `CorsPolicy` read out of front 06's
container by TYPE NAME (`rkResolve("CorsPolicy")` — the string and the annotated
binding are paired by hand, front 06's own recorded gap). A per-controller
`#[crossOrigin("https://a.test", "GET,POST")]` is keyed by the controller's
`#[route]` prefix; the LONGEST matching prefix wins, ties go to declaration
order, and an override NARROWS the global policy rather than resetting it — the
fields the decorator cannot spell come from the bean.

### Problem details, and what an "exception" is here

botopink has no exception hierarchy: `throw` is legal only under a `@Result`
return and yields an `Error(e)` VALUE, and `try … catch` works over `@Result` alone. So
`#[exceptionHandler("NotFoundException")]` has nothing to catch. What exists on
the BEAM is a raise, and rakun-web gives it one shape — `raiseProblem(tag,
detail)` raises `{rakun_problem, Tag, Detail}` in the host, and the error entry
at −100 runs the rest of the chain inside a host `try`/`catch`. **The tag is a
string, not a type name.**

- a tagged raise with a matching advice → that advice's `ProblemDetail`, served
  as `application/problem+json`;
- an untagged raise, or a tagged one nothing handles → **500**, `about:blank`, a
  correlation DIGEST in `detail`, and the full reason in the log under that
  digest. There is no property that puts the reason in the body and no
  development mode that changes it.
- a handler's own `Response` → passed through untouched. With
  `rakun.web.problemdetails.enabled=true` a bare 4xx/5xx with an EMPTY body is
  filled with the standard shape; one WITH a body is never rewritten.

The record field is `typeUri` and the JSON member is `type` (RFC 9457 §3.1); the
mapping lives once, in `problemJson`, and a cell asserts the wire carries `type`
and not `typeUri`. `jsonEscape` is asserted against a detail carrying a quote
and a newline, so a raise cannot break the document.

`#[controllerAdvice]` is type-level and `#[exceptionHandler("tag")]` a
method-level placement marker: a method `@Decl` carries no owner, so the advice
walks its own methods and does the wiring. A tag registered twice fails at boot
naming both owners.

### The matcher, and the line front 65 owns

`#[matcher("/dashboard/:path*")]` restricts an entry. **The grammar is front
65's**; front 07 executes it and invents none. Front 65 has not landed, so this
module runs exactly the three forms the two READMEs use in their own examples — a
literal segment, `:param`, and a trailing `:param*` — and REFUSES everything else
(`*`, `(`, `[`, `?`, `{`) with a located message naming front 65. A pattern that
quietly matches nothing is the failure mode decision 67 exists to prevent.

### Language notes this module is written around

- **A negative integer literal in a decorator argument does not parse.**
  `#[mark(-20)]` is `error: this token cannot appear here … unexpected 20`, on
  BOTH targets, while `#[mark(20)]` compiles. Measured against `2e6bb4ac` with
  the smallest program there is (a `pub fn mark(comptime decl: @Decl, n: i32)`
  and two one-type test files). Every order in the band below zero is therefore
  unwritable as an integer, so **`#[order]` takes a STRING** — `#[order("-100")]`
  — parsed with front 05's `toI32`, and the emitted line is
  `registerFilter("X", toI32("-100"), …)`. When the parser accepts the minus
  sign the signature becomes `n: i32` and the `toI32(` wrapper is deleted;
  nothing else moves. This is the one place this front's surface differs from
  the spec for a compiler reason rather than a design one.
- **A `@panic` message must carry no double quote.** On the erlang row
  `asserts.throwsWith` reads the `~p` RENDERING of the raised binary, in which a
  `"` inside the message is escaped to `\"`; on commonJS it reads the raw
  message. So one needle cannot match both rows if either side carries a quote.
  Measured: the needle `withHeader("Set-Cookie"` passes on commonJS and fails on
  erlang, and `withHeader(\"Set-Cookie\"` does the reverse. Every refusal in
  this module is written around it, the way front 62's are written around the em
  dash — and for the same class of reason.
- **A method on a host-supplied `behavior` does not dispatch on erlang.** See
  *The chain's request value is NOT `Request`* above; it is front 04's
  `server_test.bp:74,80` and it is why `WebRequest` exists.
- **A trailing-lambda `for` body needs its `;`.** `for (xs) { x -> f(x) };`
  is `unexpected }`; `for (xs) { x -> f(x); };` compiles. Three lines cost a
  compile each while writing `filter.bp`.
- **Wrong placement is not expressible as a cell.** `#[filter]` on a function is
  a COMPILE failure, so a file containing one has no cell to run. A clean
  compile of `test/decorators_test.bp` IS the placement assertion, exactly as
  `modules/rakun/test/di_test.bp` records for the stereotypes.
- **A registration emitted by a marker cannot be snapshotted in a file that also
  rebuilds the table.** An `@emit`ted module-load `val` lands at the END of the
  emitted module, so `test/decorators_test.bp` never resets the chain and the
  ordering cells live next door. `botopink test` runs each test FILE in its own
  process, which is what makes the split work.

### Why this member ships BOTH host files

The registries are not pure: an entry is a FUNCTION, an advice is a FUNCTION, and
no string table holds one. That is front 22's test, so `src/chain.mjs` and
`src/sidecars/rakun_chain.erl` are both this front's own files — `runtime.mjs`
stays frozen and untouched. The atom is `rakun_chain`, never `chain`:
`shipErlSidecars` skips a qualifier matching a module the build emitted,
rakun-web emits `chain`, and the skip is SILENT.

What the hosts hold: the ordered entry table (`{Order, Seq}` on an
`ordered_set`, so ties break by registration order and the table is WALKED per
request, not rebuilt), the advice table, the per-controller CORS mappings, a
boot-time key/value table, an ordering trace, and four per-request accumulators
(reply headers, `Set-Cookie` lines, the rewrite signal, the terminal closure).
What they do NOT hold: the order band, the sentinel rule, the replace-by-name
rule, the `Vary` union, the `Set-Cookie` refusal, the CORS decision, the RFC 9457
shape and every refusal message — all botopink, compiled twice, asserted twice.

The per-request four are the BEAM process dictionary and the boot-time tables are
ETS behind a dedicated owner process (`rakun_file_router`'s shape, and for the
same reason: a table dies with its creator, and a registration runs in whatever
process loaded the module).

### Front 74's `tls.bp` in this member

`modules/rakun-web/src/tls.bp` is appended to the member's `root.bp` and `files`
last, reordering nothing: it imports `filter` (the chain entry, the per-request
signal table and `withHeader`) and the core's bundle registry, and nothing in
this member imports it. It holds the web layer's side of TLS — which bundle the
listener and front 76's management listener use, the verified peer subject a
handler reads, HSTS, and the outbound bundle resolution fronts 08/09/13/15 call.
It opens no socket: the acceptor is front 04's file. See § TLS and the SSL
bundle registry.

### Steps 4 (the writer), 5 and 9 — landed with the track's second pass

- **The problem body is std's writer** (decision 116): `problemJson` is
  `json.object` over `json.quote`, which escapes every control character; the
  private `jsonEscape` (it escaped only `\n` `\r` `\t`) is gone, and a
  `detail` holding U+0001 and a `"` reads back through `json.decode` unchanged.
- **Static error pages** (`error.bp`: `errorPagePath`, `errorPageFiles`,
  `staticPage`). When nothing produced a body — the router's empty 404, a bare
  empty-bodied 4xx/5xx, or a raise no advice matched — a client that PREFERS
  HTML (`negotiation.prefersHtml`: `text/html` acceptable and above
  `application/json`) gets `<rakun.web.error-path>/<status>.html`, then
  `4xx.html` / `5xx.html`, as `text/html; charset=utf-8`; everyone else gets
  the problem detail, and a missing page or directory is not an error. A
  handler's own body and a matched advice's detail are never replaced.
- **`negotiation.bp`** is the one `Accept` reader: media ranges with q-values
  in thousandths, the most specific range deciding (`text/html` over `text/*`
  over `*/*`), an absent header meaning `*/*`.
- **Compression and server identification** (`compression.bp`, entries at 200
  and 300, installed by `installBuiltins`, which now registers five). gzip and
  deflate from erts `zlib`; `br` (or any other name) in
  `rakun.server.compression.algorithms` fails `bootWeb()` saying a NIF would be
  needed. OFF unless `rakun.server.compression.enabled=true` (Spring's default;
  a compressed secret beside attacker-chosen text is BREACH); only the media
  types of `rakun.server.compression.mime-types`, at or above
  `min-response-size` (2048). `Vary: Accept-Encoding` on every response of a
  compressible type, compressed or not. The `Content-Length` on the wire is the
  compressed body's — the acceptor measures `byte_size/1` — asserted over a real
  socket. No `Server` header unless `rakun.server.server-header` names one.
- **A compiler defect met here**: on erlang, a `return` inside an `if` that is
  itself inside an `if` block is dropped (the inner `case` falls through to
  `ok` and execution continues) — `language-gaps.md`. `errorEntry` binds the
  condition and the page first instead.

### What front 07 did NOT reach

| Step | What it needs |
|---|---|
| 6 — content negotiation | The converter registry on top of `negotiation.bp`. No blocker; it is work |
| 7 — `WebCustomizer` | `WebRegistry` with `addConverter`/`addCorsMapping`/`addFilter`/`addFormatter`, which needs step 6's converter registry first |
| 8 — API versioning | The resolution is string work with no blocker; the `Deprecation`/`Sunset` pair needs front 05 keys that exist |
| 10 — graceful shutdown | The listening socket is `rakun_runtime.erl`'s (front 04's), and front 76's `readinessDrained()` is the soft half the spec says how to land without |

## Validation — the bundled `validation` library (front 14, moved by decision 116 rule 5)

Front 14's member `modules/rakun-validation` is gone: its seven modules are the
compiler-bundled library `validation` (`libs/validation/` in the compiler repo,
`01-std/06-validation-lib`), imported by name with no dependency entry, and the
one module that names rakun's configuration — the boot refusal — is
`modules/rakun/src/config_check.bp`, with its tests in
`modules/rakun/test/config_check_test.bp`. The message lookup is injected:
`config_check.installMessageSource()` hands `validation` a `MessageSource` over
rakun's keys (`rakun.validation.locale`, `rakun.validation.messages.<code>`), and
`Rakun.run` calls it at boot, so every message key is unchanged. The member was
the only one of this workspace whose target was **both**, and the reason still
holds for the library:

> The milestone's rule is that three things cross the boundary — the serialized
> payload, the route table, and the validation constraints ("the server enforces
> / the client mirrors"). The usual way to do that is to ship a constraint
> DESCRIPTION to the client and write a SECOND evaluator in the client's
> language, which guarantees the two drift. This module does not. `#[validated]`
> emits a plain botopink function whose body is string comparisons, length
> checks and regex matches — no host cell, no `@External` anything — so ONE
> source compiles for erlang and for commonJS and the two sides run the same
> predicate. What is serialized is only the constraint table, and only for a
> consumer that is not botopink.

`test/parity_test.bp` is where that claim is held up: twenty inputs, one
function, ONE expected digest carrying every violation's field, code and
resolved message. A row that answered differently reds there rather than passing
its own half of a two-test pair.

### The naming contract with front 05

`#[validated]` on a record-shaped `type` `@emit`s exactly two functions:

```
pub fn validate<TypeName>(v: <TypeName>) -> ValidationReport
pub fn constraintsOf<TypeName>() -> string
```

The names are a contract, not a convention. Front 05's boot path builds
`validate` + the type name from the type name it already has and calls it after
binding and before the first component is constructed; it never has to know what
constraints exist. If either side changes the spelling, the build breaks rather
than a test.

`modules/rakun/src/config.bp` no longer declares a placement-only `#[validated]`:
the decorator registry is keyed by name, so a same-named marker in this package
shadowed the imported one everywhere in it (`validate<TypeName>` came out
unbound). `#[validated]` is `validation`'s, imported
`import {decorators.validated} from "validation";`. `config_check.bp` ships the
other half of the seam — `configProblem` / `refuseInvalidConfig`, which render a
refusal naming property KEYS rather than field names.

**The boot call site.** `#[configurationProperties]` on a record that also
carries `#[validated]` emits, beside its binder, `__rkCheck_<Name>() -> string`
(bind with the record's prefix, `validate<Name>`, `configProblemOf` — `""` when
valid) and `val __rkChk_<Name> = rkConfigCheckRegister("<Name>", …)` at module
load. `bootSequenceFor` installs the message source and runs every registered
check (`rkConfigCheckRun`, the refusals `\n`-joined, in registration order)
after event 3 and BEFORE the eager pass — with lazy initialization too — and an
invalid configuration is `bootFailure`: `ApplicationFailedEvent`, then the
panic carrying every violation line, and no component constructed. The table
is `?CHECKS` in `rakun_runtime.erl`; a second registration under one name
replaces the check and keeps its place. A module declaring such a record
imports `rkConfigCheckRegister` (from the core) and `configProblemOf` (from
`config_check`) beside the other emitted names. The checks are registered for
the whole run — every test file on the erlang row shares one node — so a test
that seeds an invalid value re-seeds a valid one before it ends.

### What an application must import

The emission runs at the APPLICATION site, so the application imports the names
it references — the same rule `#[service]` lives by:

```bp
import {decorators.validated, decorators.notBlank, decorators.sizeBetween, decorators.email} from "validation";
import {report: {ValidationReport, Violation}, table.constraintTableJson} from "validation";
import {constraints: {vNotBlank, vSizeBetween, vEmail}} from "validation";
```

`ValidationReport` and `Violation` are imported **even where the application never
spells them**. The erlang backend resolves a record method's owner module only
when the type is imported into the calling module; without it, `report.isValid()`
lowers to an unqualified `isValid/1`, `erlc` refuses the module and the runner
skips it silently. Measured — see § Language notes below.

### The constraint set

| Marker | Applies to | Holds when |
|---|---|---|
| `#[notNull]` | a field whose type can be null (reflects as `""`) | the value is not `null` |
| `#[notBlank]` | `string` | trimmed length > 0 |
| `#[notEmpty]` | `string`, `Array<T>` | length > 0 |
| `#[sizeBetween(min, max)]` | `string`, `Array<T>` | `min <= length <= max`, both ends inclusive |
| `#[minValue(n)]` / `#[maxValue(n)]` | `i32`, `f64` | numeric bound, inclusive |
| `#[positive]` / `#[positiveOrZero]` | `i32`, `i64`, `f64` | sign |
| `#[email]` | `string` | `^[^@ ]+@[^@ .]+([.][^@ .]+)+$` |
| `#[pattern(regex)]` | `string` | `std/regex.matches` |
| `#[pastDate]` / `#[futureDate]` | `i64` epoch millis | strictly before / after `std/io/clock.nowMillis()` |
| `#[constraint(name)]` | `string` | the registered constraint named `name` answers `""` |

There is **no `#[future]`**: the name reads as the `future` effect annotation
that decision 118 removed (a `-> @Task<…>` return replaced it), and a marker
that looks like a removed effect is a trap. The temporal markers are
`#[pastDate]` and `#[futureDate]`.

`#[sizeBetween]` takes BOTH bounds because a declared parameter default is never
applied at a call site; Spring's single `@Size(min = …)` with the other half
optional has no botopink spelling, and pretending otherwise would produce a
decorator that silently drops an argument.

### Refusal beats a constraint that could never fail

Decision 67, applied to a validator. The failure mode this module exists to
design out is a validator that silently passes what it cannot check, so:

- A marker on a field whose type it cannot check is a **located compile error**,
  not a row that quietly always passes — `#[notBlank]` on an `i32`, `#[minValue]`
  on a `string`, `#[pastDate]` on an `i32`, `#[notNull]` on a field that can
  never be null, `#[sizeBetween(50, 2)]`, `#[pattern("")]`.
- `#[constraint("cpf")]` with nothing registered under `cpf` produces a
  violation coded `unknownConstraint` at the first validation call, with the
  name and the registered list in the message. It never passes.
- `bindInt("age", "12x")` answers `0` **and** records a `typeMismatch`, so the
  zero can never be mistaken for a value the caller meant.
- `refuseInvalidConfig` is an `assert`. There is no flag that turns it into a
  warning.

### The constraint table, and why it is a blob

`constraintsOf<Name>()` is emitted as a CALL — `constraintTableJson("<Name>",
"<blob>")` — rather than as a JSON string literal. A decorator body that wrote
the JSON itself would be writing a string literal INTO source (two levels of
escaping), and the grammar would live in a comptime body no test can call. The
blob grammar is `<field>|<code>[|<arg>]*`, records separated by `;`, and an
argument carrying `;`, `|` or `"` is refused by the marker that takes it — so
the grammar has no escape and needs none. Front 72's condition blob is the same
shape for the same reason.

### The SPI, and the shape the language admits

```bp
pub behavior Constraint {
    fn code(self: Self) -> string;
    fn check(self: Self, field: string, value: string) -> string;  // "" when acceptable
}

pub fn registerConstraint(name: string, code: string, check: fn(field: string, value: string) -> string) -> i32
```

The front's spec writes `registerConstraint(name: string, c: Constraint)`. A
record that `implement`s a behavior does **not** coerce to the behavior type
anywhere — not as a call argument, not under a `val` type annotation, not as a
return type (measured on both rows). So the registration passes the behavior's
two methods instead: the type still `implement`s `Constraint`, so the compiler
still checks the shape, and a closure is what crosses. An application writes:

```bp
pub type CpfConstraint {
    pub fn code(self: Self) -> string { return "cpf"; }
    pub fn check(self: Self, field: string, value: string) -> string { … }
}

val __cpf = CpfConstraint();
val __cpfRegistration = registerConstraint("cpf", __cpf.code(), { f, v -> __cpf.check(f, v) });
```

### Why this member ships BOTH host files

Two things it needs are not values: the SPI registry, which maps a name to a
`Constraint` (no string table holds a closure), and the binding accumulator,
which the `bind…` readers append to (records are immutable, so a binder record
cannot accumulate as it goes). `src/validation_host.mjs` and
`src/sidecars/rakun_validation.erl` are the two halves. Neither decides
anything: every predicate, every template, every refusal text, the table and the
report's JSON are botopink on both rows.

The accumulator's SCOPE is the one place the rows differ, and it is the one
place `bindingIsolated()` asks the host rather than answering itself: the BEAM
half MEASURES it by spawning a child, pushing there, and comparing this
process's count; the node half states it about a row whose dispatcher runs one
request to completion before it reads the next — the same claim
`request_context.mjs` makes about the request frame.

### Language notes this module is written around

Each measured against the pinned binary, not guessed.

- **A record that `implement`s a behavior does not coerce to the behavior type.**
  `fn greet(g: Greeter)` called with an `En` that implements `Greeter` is
  `type mismatch: expected Greeter, got En` on both rows; so is
  `val g: Greeter = En(…)` and `fn f() -> Greeter { return En(…); }`. The SPI is
  written around it (above).
- **An integer literal does not widen to `i64` in arithmetic.** `fn shrink(x:
  i64) -> i64 { return x - 1000; }` is `type mismatch: expected i64, got i32` on
  both rows, **with no line or column** — only the file. A COMPARISON widens
  (`x > 0` is fine) and so does a call argument bound to an `i64` PARAMETER from
  an `i64` VALUE; an `i32` literal passed where an `i64` is expected does not
  (`vPastDate("a", 1)` reds, located). There is no `i64` literal spelling, so a
  test that needs one builds it from the clock
  (`clock.nowMillis() - clock.nowMillis()`). This is why `#[minValue]`/`#[maxValue]`
  are REFUSED on an `i64` field rather than emitted as something that reds, and
  why `parseI64` is the module's only host cell in the coercion path.
- **A record method's owner module is resolved only when the type is imported.**
  On erlang, calling a method on a value whose type is not imported into the
  calling module emits an unqualified local call: `erlc` answers
  `function doubled/1 undefined`, the runner prints NO summary for that module,
  and the command exits 127. commonJS is green on the same source. Minimal
  repro: a `Box` with a `doubled()` method in one module, a `make() -> Box` in a
  second, `assert make().doubled() == 42` in a test that imports only `make`.
- **A field's reflected `typeName`**: `string` / `i32` / `i64` / `f64` / `bool`
  render as themselves; **`?string` and `string[]` both render as `""`**;
  **`Array<string>` renders as `"Array"`**. Identical on both rows. (Front 05's
  `#[configurationProperties]` reads an empty name as "a list", which is right
  for `string[]` and wrong for `?T`, and does not handle the bare `"Array"` its
  own comment says is empty — see § Blocked.)
- **An annotation's `args` are RAW LEXEMES**, quotes included: `#[pattern("^a$")]`
  reflects as `["\"^a$\""]`. They are the right text for the emitted CALL and
  need `.replaceAll("\"", "")` for the blob — which is exact only because each
  marker refuses an embedded quote in its own body.
- **A `type` with an empty field list `()` is refused** (`type-empty-field-list`);
  a `type X { … methods … }` with no field list at all is fine.
- **`String.replaceAll` is LITERAL on both rows** (`binary:replace(…, [global])`
  / native `replaceAll`), which is what makes `jsonEscape` safe escaping the
  backslash first.
- **A nested closure may write a `var` of the enclosing decorator body**, and may
  `push` onto an `Array` declared there — `#[validated]`'s per-annotation walk is
  two levels deep and accumulates both the emitted calls and the blob rows.

### What front 07 and front 78 consume from this front

`validate<TypeName>` by name (front 07's `ValidationFilter` runs a route's
registered binder before the handler, which is the closest thing to Spring's
`@Valid` parameter and belongs to that front's chain, not to this module's
decorators) and `ValidationReport.toProblemDetail()`, so an application has ONE
error shape and not a second one for validation.

## TLS and the SSL bundle registry — front 74

`modules/rakun/src/ssl_bundle.bp` names TLS material ONCE and lets five
subsystems refer to it by name, which is Spring 3.1's answer to "the HTTP
client, the SQL driver, the Redis connection and the broker each invent three
properties for a certificate". `modules/rakun-web/src/tls.bp` is the seam
between that registry and the request path.

**Measured 2026-09-21 against compiler `2e6bb4ac`, with fronts 04–07, 14, 22,
23, 62 and 72 in the tree.** `modules/rakun`: **387/387** on commonJS (was
346/346) and **385 passing / 2 failing** on erlang (was 344/2) — the two still
front 04's `server_test.bp:74,80`. `modules/rakun-web`: **104/104** on BOTH rows
(was 83/83). Neither pinned row in
`botopink-lang/scripts/restricted-targets.txt` moves: `rakun-web commonJS 0`
stays `0`, core rakun's `2` stays `2`.

### Why this front ships BOTH host files where its spec said erlang only

The spec declares every host seam `#[@External.Erlang("rakun_ssl", …)]` only,
because `ssl` and `public_key` are OTP applications with no Node form. That is
true of `ssl:listen/2` and false of everything the registry needs. And the
measured shape decides it: `botopink test` compiles every `test/*.bp` on BOTH
rows with no per-target gate, so a cell carrying only an `#[@External.Erlang]`
form is a located diagnostic AT THE CALL SITE on the node row — a single
erlang-only cell behind a called wrapper takes the whole member off commonJS,
which is the row `modules/rakun` is pinned on. So `src/ssl_bundle.mjs` sits
beside `src/sidecars/rakun_ssl.erl`, every cell carries both forms, and
`test/ssl_bundle_test.bp` is one set of assertions run on both rows. Front 07
resolved it the same way (`chain.mjs`), and front 05 the same way again
(`config.bp` over `std`'s `fs` rather than a `rakun_config.erl`).

The erlang-only work is in the sidecar as plain functions no `.bp` cell names:
`listen_options/1`, `connect_options/2`, `transport/1` and `handshake_timeout/1`
— the exact shape front 04's acceptor takes when it swaps `gen_tcp` for `ssl`.
They are covered by reading, not by a cell, which is front 04's own arrangement
for its four node-twinless cells and front 07's for `rakun_chain:run/6`.

### What the hosts hold and what they do not

They hold a two-level table (`name` → `field` → value, in registration order),
an X.509 field reader (`public_key:pkix_decode_cert/2` / `crypto.X509Certificate`)
and a certificate/key correspondence check. They do NOT hold the property
grammar, the defaults, the posture mapping, the option-list ENCODING, the JKS
refusal, the reload rule or any refusal text — all botopink, compiled twice and
asserted twice.

The two rows agree byte for byte on `certInfo`, which took a rendering contract:
node answers newline-separated RDN attributes and OTP an `rdnSequence` of OID
tuples, so both canonicalise to `CN=…,O=…` in certificate order; the instants are
`YYYY-MM-DDTHH:MM:SSZ`; `daysRemaining` is floored on both. The one thing the
rows word differently is the `error|` reason for text that is not a certificate
(node quotes OpenSSL, OTP names the missing PEM block), and the suite asserts
that there IS a reason rather than which.

### One text, two deliveries

`bundleProblem(b)` answers the refusal as a STRING and `validateBundle(b)`
raises it. `sslBundle` and `sslBoot` raise; `sslRegister` and `sslReload` record.
A reload runs at 3am, on a timer, in a process that has to survive a file being
late — a refusal that raised there would take a running service down over a file
that is merely slow to appear. There is one text and the suite asserts both
deliveries of it.

### A failed reload keeps the previous material by ORDERING

`sslRegister` reads the files, parses the certificate and checks the key BEFORE
it writes a single registry row, so a failure records the reason and every row
the previous resolve wrote is still where it was. This started as an explicit
save-and-restore; a planted defect that disabled the restore **redded nothing**,
which is how the branch was found to be dead. It is gone. An unassertable branch
is worse than no branch.

### The certificate the suite parses is deliberately EXPIRED

The spec refuses a committed fixture because "a committed certificate expires and
turns a whole front red on a date nobody chose", and asks instead for
`rakun_ssl:selftest_material/1` to generate a CA and two certificates through
`public_key` at setup. That generator is erlang-only — node has no X.509 issuance
API at all — so it would move every assertion off the commonJS row. A
self-signed certificate whose window CLOSED in April 2020 has no date to rot on:
its subject, issuer, notBefore and notAfter are constants and `daysRemaining` is
negative today and more negative tomorrow. Nothing asserts a positive number of
days from it, and the material is embedded in the test file rather than
committed as a fixture path.

The consequence is what this front could NOT reach: every acceptance that needs a
certificate with a CHOSEN validity window — `OUT_OF_SERVICE` at three days, `UP`
at thirty — is asserted against `sslHealthOf(days, lastError, threshold)`, a pure
function, with synthetic numbers. Closing it needs `selftest_material/1` plus a
`.bp` test file that can declare its target.

### Names are a LIST, and exactly what would close that

Spring discovers bundle names by walking the property tree for
`spring.ssl.bundle.pem.*`. There is no key enumeration on either row: front 04's
`?PROPS` ETS table is `public` and could be folded over, but `runtime.mjs`'s
`props` is a module-private `Map` with no export, `runtime.mjs` is FROZEN for the
milestone and it is this front's `Does not touch`. So `sslBundleNames()` reads
`rakun.ssl.bundle.pem` as a comma-separated scalar (or the indexed keys a YAML
sequence flattens to) through front 05's `rkPropList` — front 05's own idiom for
`rakun.config.catalogue`. Closing it needs ONE cell with two halves,
`rkPropKeys(prefix) -> string`: `ets:foldl` over `rakun_props` and a
`props.keys()` export in `runtime.mjs`. Only `sslBundleNames()`'s body moves.

### The transport seam, and the one asymmetry

OTP's `ssl` exposes the same five functions with the same shapes as `gen_tcp`, so
front 04's acceptor takes the transport MODULE as a variable rather than
branching — `ranch_tcp`/`ranch_ssl`'s arrangement. `rakun_ssl:transport/1` answers
the module and `listen_options/1` the option list. The asymmetry is the
handshake: `ssl:handshake/2` must run in the process that will OWN the socket, or
a slow or hostile client blocks every other connection from being accepted, so
the connection process performs it as its first act bounded by
`handshake_timeout/1`. **`rakun_runtime.erl` is not edited by this front** — it
is front 04's file — so the swap is written and not wired, and no cell asserts a
completed handshake.

### Language notes this module is written around

- **A test file that imports `std`'s `process` loses EVERY cell in it on the
  commonJS row.** The emitted test module declares `const process = …` at module
  scope, shadowing node's global, and the harness's own `__bp_run_tests` reads
  `process.argv[2]` — so the file dies with `TypeError: Cannot read properties
  of undefined (reading '2')` before any cell runs. The run EXITS 1, so a gate
  catches it; what disappears is the COUNT LINE. The file contributes no
  `N passed, M failed` at all, where the same file without the import prints
  `1 passed, 0 failed`. Silent to the count, not to the exit code — which is the
  property that lets it survive in a suite somebody reads by eye. Clean on
  erlang. Measured against `2e6bb4ac` and again against `4fe1747e`, with a
  two-file package whose only content is `import {process} from "std";` (today
  `import {io.process} from "std";`) and one
  trivial assertion. A `src` module may import it; a `test` module may not — and
  the place the next reader will reach for it is `absolutePath`'s cell in
  `test/ssl_bundle_test.bp`, where the comment says so.
- **`fs.exists` disagrees about a character device.** `/dev/null` is `true` on
  node (`existsSync`) and `false` on the BEAM (`filelib:is_file/1`, which covers
  regular files and directories). A test needing "a path that exists" writes a
  real file; it does not point at a device node.
- **A `throwsWith` thunk must answer `i32`.** `{ -> sslRegister("x"); }` is
  `type mismatch: expected i32, got bool`; `{ -> sslRegister("x"); 0; }` compiles.
- **No double quote in a refusal text.** Front 07's measurement, and one cell
  here asserts the property over all ten refusal strings at once rather than
  leaving it to review.

### What front 74 did NOT reach

| Step | What it needs |
|---|---|
| 2 — the server listener, end to end | An edit to `modules/rakun/src/sidecars/rakun_runtime.erl` (front 04's acceptor) to take the transport module from `rakun_ssl:transport/1` and move the handshake into the connection process. The option list, the timeout and the transport decision are all written and asserted; the acceptor is not this front's file |
| 3 — mutual TLS, end to end | The same acceptor edit, plus `ssl:handshake/2` writing the verified peer subject into the request. `peerSubject()`/`peerVerified()` and the "never read an unverified subject" rule are written and asserted against the signal table; what is missing is the producer |
| 5 — the mtime watcher as a `gen_server` | Front 16's scheduler. The poll body (`sslPoll()`) is written and asserted, including that `reload-on-update=false` makes no filesystem call; an erlang `gen_server` cannot call it, because the reload is botopink (`std`'s `fs` and the refusal texts) and a sidecar cannot call back into botopink |
| 6 — registration with front 11's SPI | Front 11's `HealthIndicator` and `InfoContributor` behaviors, which have not landed. `sslHealth()` and `sslInfo()` produce the two contributions and are asserted; only the registration is missing |
| 6 — an expiring certificate, end to end | `rakun_ssl:selftest_material/1` (erlang-only) plus a `.bp` test file that can declare its target. `sslHealthOf` covers the verdict table with synthetic numbers |
| PKCS#12 | `public_key`'s PKCS#12 support and a refusal naming the OTP version when it cannot decode. PEM is what is implemented; a `.p12` today fails as "not a PEM certificate rakun can read", which names the file but not the format |

## Design at a glance

- **IoC container** — components (`#[component]`/`#[service]`/`#[repository]`/
  `#[controller]`/`#[restController]`) are scanned at module load; each gets an
  emitted **singleton** factory `__rkMake_<Type>()` (`rkSingleton` — one instance
  per type, shared across a 3-level chain / diamond).
- **Constructor injection** — a dependency is declared as a field of the `type` and
  resolved **by type** (the factory calls the field type's own factory).
  Immutable-first: no setter/field injection.
- **`#[value("key")]` property injection** — a `#[value]` field is filled from the
  config source (`rkProp`/`rkPropInt`), **excluded** from the DI graph (the factory
  reads `f.annotations` to detect it). `#[configuration]` + `#[bean]` register a
  `__rkMake_<ReturnType>()` so a bean's return type is injectable by type.
- **Cycle detection** — `__rkMake_X` brackets construction with `rkEnter`/`rkDone`;
  a cycle A→B→A raises at first construction. (A *comptime* cycle diagnostic would
  need a whole-graph view no single decorator has — a recorded follow-up.)
- **Web layer** — `#[restController, route(prefix)]` + `#[getMapping(path)]`/… emit
  a `rkRegisterRoute(verb, prefix + path, handler)`; `rkDispatch`/`rkDispatchHttp`
  match (verb, path) — including `:name` params — and run the handler over a live
  `Request`/`Response`, or 404. `rkRegisterRoute` is generic over the request type
  so the emitted closure's `req` unifies nominally with the handler's `Request`.
- **Bootstrap** — `Rakun.run(App(port: 8080, basePath: "/api"))` (`bootstrap.bp`)
  reads the router back and starts `rkServe` (node `http`), dispatching each live
  request via `rkDispatchHttp`. The runtime `.mjs` files ship next to the emitted modules (G2).

## Conventions

- **`.bp` over `.d.bp`.** Logic lands in real emitted `.bp` (`http.bp` incl. the
  `Request` behavior, `runtime.bp`'s `declare fn`s, `decorators.bp` bodies,
  `bootstrap.bp`). Only the future `Context` behavior stays declaration-only in
  `rakun.d.bp`. `Request.param`/`query`/`header` return a plain `string` (`""` when
  absent), not `?string` — behavior-method optional returns don't yet get the
  `@Option` lowering, and a required path var / empty default is the cleaner contract.
- **Host state behind `#[@External.Node]`.** The one mutable seam is `runtime.mjs`; the
  core never sees it. Decorator bodies obey the comptime constraints (no sibling
  calls, `if`-expr, bare-`if` only last, block-lambdas) — see
  [`../botopink-lang/modules/compiler-core/src/comptime/AGENTS.md`](../botopink-lang/modules/compiler-core/src/comptime/AGENTS.md).
- **Imported, not prelude.** Reached via `from "rakun"` — never auto-loaded into
  the type `Env`, no core embed/registry.
- **Tests live here.** rakun's tests are `test { … }` blocks inside its own
  `.bp` files (run by `botopink test`), NOT in the compiler's Zig test suites.
  Wrong-placement *rejection* is covered generically by the compiler's
  annotation-processor suite (a compile-failure can't be a runtime `assert`).
- Keep this file in sync with `docs.md` and the spec in the same change.

## See also

- The spec (intent, steps, test scenarios) → [`../../tasks/v0.beta.11/specs/rakun.md`](../../tasks/v0.beta.11/specs/rakun.md).
- The runnable end-to-end app → [`./examples/rakun/`](examples/rakun/).

## CI

`.github/workflows/test.yml` runs `zig build test-libs -- --lib rakun
--target <t>` for `{commonJS, erlang, beam}` on `ubuntu-22.04` +
`macos-14`, plus `commonJS` on `windows-2022`. Under the workspace, `--lib rakun`
restricts the runner to the **core member** (the umbrella has no row); without
`--lib` the runner discovers every member of the workspace — one row each,
the scaffolds as compile-only `–` cells and the example as an application. No `wasm` cell —
rakun's server surface targets node + the BEAM. The `erlang` rows keep
`allow_fail: true` (see the `botopink.json` note above for what actually blocks
them). `BOTOPINK_LANG_REF` repo variable pins a specific botopink-lang ref
(default `feat`).

Bootstrap: check out this lib + a fresh `botopink-lang` clone, place
this lib under `botopink-lang/repository/rakun/`, then `zig build
install && zig build test-libs`.

## Tagging (auto)

`.github/workflows/tag.yml` reads `version` from `botopink.json` and
tags every push to `feat`/`master`/`main`:

- **feat** → moving `<version>-feat` tag (force-pushed on every push).
- **master** / **main** → immutable `<version>` tag. Pushing the same
  SHA twice is a no-op; pushing a *different* SHA without bumping
  `version` is a hard error (bump it in `botopink.json` to publish a
  new release).

Set `requires.rakun = "feat"` in a consumer's `botopink.json` and run
`bpmp sync` to preview unreleased work.

## Local gate

`scripts/git-hooks/pre-commit` is the tracked pre-commit gate. It is
self-contained: it sources `scripts/git-hooks/lib/runner-standalone.sh`
from this repository and reaches nothing outside it, so a standalone
clone, a checkout inside the botopink meta workspace and a worktree run
the same gate. Install it once per clone:

```sh
git config core.hooksPath scripts/git-hooks
```

`core.hooksPath` is per clone and applies to every worktree of it. The
gate checks staged files for conflict markers, then — because the root
`botopink.json` is a workspace — runs `botopink test` **inside every
`modules/*/` that holds a `botopink.json`**, each on its own manifest
target (`erl` and `node` on `PATH`); a red member fails the gate and names
the re-run command. (A root manifest without `"workspaces"` keeps the old
single `botopink test` over `src/` + `test/`.) The compiler binary is located via (in order)
`$BOTOPINK_BIN`, the nearest ancestor
`repository/botopink-lang/zig-out/bin/botopink`, then `$PATH`. If none
resolve, the gate prints a yellow warning and exits 0 — CI runs the full
suite and catches any regression there. Never commit with `--no-verify`;
fix the red instead.

After `botopink test`, the gate builds every `examples/*/` that has a
`botopink.json` (`runExamplesGate`, each with its own manifest target,
into a throwaway `--out`); CI runs the same function once per workflow.
`scripts/known-broken-examples.txt` lists the examples allowed to fail —
`examples/<name>  <reason>` per line — and cannot rot: a listed example
that builds, or a listed path that no longer exists, fails the gate too.
When a fix makes an example build, delete its line in the same commit. The list may be absent,
empty or hold only `#` comments — each means no example is allowed to fail.
`examples/rakun` (member `rakun-example`, depending on `rakun` through
`{ "workspace": true }`) builds; nothing is listed. Until the erlang-only move it
also **ran** on node — and runs again on the BEAM once a built erlang program ships
and loads its sidecars (§ Module tree, "What the move costs"): `botopink run`
inside it serves `GET /api/users/` → `ana, bob, cleo`, `GET /api/users/ana` →
`Hello, ana!`, `GET /api/posts/` → `hello world | rakun rocks`,
`POST /api/posts/` → 201 `created: hi` and `GET /api/nope` → 404, which is what
its `src/main.bp` header documents. Its `main.bp` imports the whole type
closure of each module it uses (`UserController`, `UserService`,
`UserRepository`, `Request`, `Response`, …): importing a type re-checks its
declaration in the importing module, so every type its fields and method
signatures name has to be in scope there too, or the build reds with
`unknown type '<Name>'`.
