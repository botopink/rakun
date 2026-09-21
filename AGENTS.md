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
router table — live in `runtime.mjs`, reached through the `#[@External.Node]`
declarations in `runtime.bp`. The emitted code references those runtime fns by
name, so a module declaring components also imports them (`import {service,
rkScan, rkSingleton, rkEnter, rkDone, rkRegisterRoute, …} from "rakun"`). The HTTP
value types + the `Request` behavior are real emitted code (`http.bp`);
`Rakun.run` (`bootstrap.bp`) starts rakun's own node `http` transport
(`rkServe` → `serve` in `runtime.mjs`).

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
├── botopink.json      ← WORKSPACE: name rakun · version · targets [commonJS, erlang] (the default
│                        every member inherits and may only restrict) · workspaces
│                        ["modules/*", "examples/*"]. Nothing importable from it.
├── modules/
│   ├── README.md      ← the member table (14 today, 13 planned with their fronts), the
│   │                    module ↔ Spring starter map, how to add a member
│   ├── rakun/         ← THE CORE — what `from "rakun"` gives a consumer
│   │   ├── botopink.json  name rakun · entry root.bp · target commonJS · targets [commonJS]
│   │   │                    (erlang joins when § Blocked closes) · files: root · http ·
│   │   │                    runtime · decorators · bootstrap · rakun.d · no dependencies.
│   │   │                    The `.erl` sidecar is NOT a `files` entry: `shipErlSidecars`
│   │   │                    finds it under the package's `src/sidecars/`
│   │   ├── src/
│   │   │   ├── root.bp        ← module-tree root: `pub mod decorators; http; runtime; bootstrap;`
│   │   │   ├── http.bp        ← concrete, emitted: `HttpMethod` enum-shaped type · `Response` type
│   │   │   │                    (builders) · `App` config · `Request` behavior
│   │   │   ├── runtime.mjs    ← host runtime: the mutable seams (scan list · singleton cache ·
│   │   │   │                    cycle guard · config props · router table + dispatch/dispatchHttp)
│   │   │   │                    + the node `http` transport (`serve`)
│   │   │   ├── runtime.bp     ← the host cells, each carrying BOTH an `@External.Node` and an
│   │   │   │                    `@External.Erlang` form (`rkScan`/`rkSingleton`/`rkEnter`/
│   │   │   │                    `rkDone`/`rkProp`/`rkRegisterRoute`/`rkDispatch`/
│   │   │   │                    `rkDispatchHttp`/`rkServe`/…); sibling `./runtime.mjs` shipped
│   │   │   │                    next to the emitted module (G2)
│   │   │   ├── sidecars/
│   │   │   │   └── rakun_runtime.erl ← THE ERLANG HOST MODULE (§ The erlang host module):
│   │   │   │                    the `application` + supervision tree + ETS tables behind
│   │   │   │                    every `@External.Erlang` cell. Shipped by
│   │   │   │                    `shipErlSidecars`; the atom may not be `runtime`
│   │   │   ├── decorators.bp  ← the markers AS comptime decorator fns: placement rules +
│   │   │   │                    the DI/router/scope/bean wiring they `@emit`
│   │   │   ├── file_router.bp ← the FILE-CONVENTION route table (§ The file-convention
│   │   │   │                    route table): the segment grammar, the `kind|pattern|
│   │   │   │                    slot|verb` wire format, the matcher and the four
│   │   │   │                    markers. `decorators.bp` is frozen, so the markers
│   │   │   │                    live here, as `#[configurationProperties]` does
│   │   │   ├── file_router.mjs ← the App-Router REGISTRY, node half: an append-only
│   │   │   │                    list of (wire line, render fn). Knows no grammar
│   │   │   ├── sidecars/rakun_file_router.erl ← the same registry on the BEAM, in
│   │   │   │                    ETS behind a dedicated owner process
│   │   │   ├── request_context.bp ← THE REQUEST CONTEXT (§ The request context):
│   │   │   │                    the frame, its epoch, the five phases and the
│   │   │   │                    refusal texts. Every accessor raises outside a
│   │   │   │                    request and there is no flag that changes it
│   │   │   ├── request_memo.bp ← the `React.cache` analogue over the frame's
│   │   │   │                    table: `memoize` · `preload` · `memoKey`
│   │   │   ├── request_context.mjs ← the frame, node half: a module-global slot
│   │   │   │                    store. Knows no phase, no header, no cookie
│   │   │   ├── sidecars/rakun_request_context.erl ← the frame on the BEAM: ONE
│   │   │   │                    process-dictionary key plus an ETS area that
│   │   │   │                    outlives it, for work that runs after the response
│   │   │   ├── bootstrap.bp   ← `Rakun` (concrete type): `Rakun.run(app)` starts `rkServe`
│   │   │   └── rakun.d.bp     ← declaration-only: the `Context` IoC behavior (future)
│   │   └── test/
│   │       ├── di_test.bp     ← placement + component scan
│   │       ├── router_test.bp ← DI chain + router dispatch (200 / 404) end to end
│   │       ├── scopes_test.bp ← singleton scope (diamond) · `#[value]` · `#[bean]` (F2-scopes)
│   │       ├── server_test.bp ← the live HTTP dispatch pipeline (`rkDispatchHttp`): path
│   │       │                     param · query/header/body · 200/404 (F5)
│   │       ├── file_router_test.bp ← the segment grammar · the wire-format round
│   │       │                     trip · matcher precedence and capture · the layout
│   │       │                     chain · the registry cells. The SAME assertions on
│   │       │                     both rows
│   │       ├── file_router_markers_test.bp ← the four markers at module level and
│   │       │                     the accessors they emit; no `rkAppReset()`, because
│   │       │                     a module-load registration cannot be snapshotted in
│   │       │                     its own module
│   │       ├── request_context_test.bp ← the frame lifecycle and the epoch
│   │       │                     discipline, the keep-alive case FIRST
│   │       ├── request_memo_test.bp ← hit/miss counts, per-request lifetime,
│   │       │                     preload single-flight, non-poisoning
│   │       ├── file_router_scan_test.bp ← the scan over real fixture trees under
│   │       │                     `test/fixtures/{routing,conflict-both,conflict-roots,
│   │       │                     middleware}`: the conflicts, the `_` skip, `app` vs
│   │       │                     `src/app`, the root `middleware.bp`
│   │       ├── overlapping_routes_test.bp ← two controllers sharing a path prefix both
│   │       │                     register; dispatch matches the FULL path; a leaf (no-dep)
│   │       │                     #[service] resolves through the DI chain
│   │       └── erlang_runtime_test.bp ← the host cells named DIRECTLY (no decorator):
│   │                             scan order · singleton/build count · the parseInt rule ·
│   │                             route order · the `Response` round-trip shape. The same
│   │                             assertions on BOTH rows — green on commonJS and on erlang
│   └── rakun-<area>/  ← the thirteen scaffolds (actuator · cache · client · data · hateoas ·
│                        logging · messaging · scheduling · security · session · test ·
│                        validation · web): `botopink.json` (files [root.bp] · targets per
│                        `specs/1.0.10-beta/03-rakun/modules.md` § Targets · dependencies
│                        { "rakun": { "workspace": true } }) + a two-comment `src/root.bp`;
│                        contents land per front
├── examples/
│   └── rakun/         ← member `rakun-example` (an application: entry main.bp, target commonJS,
│                        depends on `rakun` via { "workspace": true }); the sixty-second app
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
out of `root.bp`. rakun declares **no dependencies**: the HTTP transport
`Rakun.run` starts is `serve` in its own `runtime.mjs` (bound as `rkServe`), so a
consumer declares only `rakun`. (It used to name a `server` library that exists in
no repository — `botopink check` failed with `LibNotFound` before reading rakun's
source.)

The core's `botopink.json` carries both target keys on purpose: `"target": "commonJS"` is
the build target the CLI reads (`config.zig`), and `"targets": ["commonJS"]` is
the per-member whitelist `botopink-lib-test` reads (`lib-test-runner/src/discovery.zig`)
to skip the erlang/beam cells. The workspace's `targets` is `["commonJS", "erlang"]` — the default a
member inherits when it declares none — and a member may only **restrict** it, so the core's
`["commonJS"]` is a restriction and dropping it would widen the core's matrix to a red erlang cell,
not fix a no-op key. Front 04 built the erlang host module (§ The erlang host module) but did
**not** widen `targets`: `botopink test --target erlang` is 21 passing / 6 failing and one test
file that does not compile, and every one of those reds is an erlang-BACKEND gap listed in
§ Blocked, not rakun's. `erlang` joins `targets` in the change that closes them — widening it
now would only move a known red into the gate. rakun has no line in
`botopink-lang/scripts/known-red-libs.txt` (that file lives in the compiler repository and
currently holds only its header), so there is nothing to delete there either.

## The erlang host module

`modules/rakun/src/sidecars/rakun_runtime.erl` is the erlang twin of
`runtime.mjs`. Every host cell in `runtime.bp` now carries two forms —
`@External.Node("./runtime.mjs", "<camelCase>")` and
`@External.Erlang("rakun_runtime", "<snake_case>")` — and the two answer
identically: `test/erlang_runtime_test.bp` is one set of assertions run on both
rows, which is the only statement worth making about a port.

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

`runtime.mjs` is frozen for the milestone, so four pieces of the erlang host
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
> line, in front 04's file, and front 05 does not touch it. `targets` stays
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

`modules/rakun/src/file_router.bp` is the second routing model, beside — not
instead of — `#[restController]` + `#[getMapping]`. A URL comes from where a
file sits: `layout.bp` wraps everything below it, `page.bp` makes the route
public, `(group)` is transparent to the URL, `@slot` renders into a named prop
of the parent layout, `_private` is excluded from routing and
`[slug]` / `[...slug]` / `[[...slug]]` capture instead of matching.

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
assertions are green on both rows, but `botopink test --target erlang` for the
member is 134 passing / 2 failing, and the two reds are front 04's `request/6`
(`{badkey,param}` / `{badkey,query}`), not this front's. Widening `targets` now
would move a known red into `botopink-lib-test` rather than fix anything, which
is the call front 04 and front 05 each made for the same reason. `erlang` joins
in the change that closes them.

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
| `#[page]` on a fn returning `Element` | `#[page] must annotate a #[@future] fn returning @Future<Element> — every page is async so the render pipeline has one shape to drive` |
| `#[layout]` on a `#[@future]` fn | `#[layout] must annotate a fn(props: LayoutProps) -> Element — a layout is synchronous, only a page is a @Future` |
| `#[page()]`, `#[page(1)]` | the automatic argument check, with no code in this front |

Three measurements shape these bodies and one of them is new:

- **A named function used as a VALUE does not lower on the erlang row.**
  `rkAppPage("blog", blogPostPage)` compiles on node and is
  `variable 'BlogPostPage' is unbound` on erlang. The markers therefore emit
  `{ route -> blogPostPage(route) }`, which is the same value, lowers on both,
  and is what `decorators.bp` already emits for a controller method.
- **`decl.returnType` carries no type argument.** It is `"Future"` for
  `-> @Future<Element>`, `"Element"` for `-> Element` and `""` for a type. So a
  page is checked to BE a `Future` and a layout to be anything that is not one;
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
recorded it), `std`'s `unicode` module is `undef` on the erlang row from here,
and `charCodeAt` answers a UTF-16 code unit on node against a codepoint on the
BEAM: three reasons the two rows cannot be made to agree about a non-ASCII
octet. A CONTROL character percent-encodes — that is how "a `Set-Cookie` line
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

**Two deviations from the front's text, both because front 01 has not landed.**
`libs/std` has no `hmac`, no `clock` and no `encoding` module today, so the
signature is `crypto.hmacSha256` (hex, not base64url) and the token is
`crypto.randomBytes(16)` (hex too). Both carry an `@External.Node` and an
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

**`preload` is not built on `@Future`, and cannot be.** On erlang `@Future<T>`
lowers eagerly — `libs/std/src/http.bp` says so in as many words — so `await` is
identity and a future is a value that has already been computed. `preload`
therefore spawns a monitored child and stores a PENDING marker holding its pid;
a later `memoize` with that key waits on the monitor rather than starting a
second load, and a child that dies without answering is not a poisoned key (the
waiter runs the loader itself). There is no third state in which the frame holds
an unresolved future. Node has no process, so `preload` there runs the loader
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
- **A `from "std"` module imported by a `test/` file is `undef` on the erlang
  row; imported by a `src/` module it works.** `std/crypto`, `std/base64`,
  `std/time` and `std/unicode` each answer `{error, undef}` when a test file
  imports them directly, and each answers correctly when the same call is
  reached through a `pub fn` in `src/`. The emitted module is
  `.botopinkbuild/test-out/std/<name>.erl` with the atom `std@<name>`; a std
  module the LIBRARY's own sources pull in (`std@dict`, `std@fs`) is loaded and
  one only a test names is not. So `request_context.bp` imports `std/crypto`
  and the test reaches it through `draftSign`. `std/asserts` is the exception
  that proves nothing: the test harness pulls it in itself.
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

`rkConfigLoad()` is the entry point and the ONE `#[@result]` seam: a missing
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
  built through `charOf`/`sub`.
- `Array.pop` is `lists:last/1` on the erlang row — it READS the last element, it
  does not remove it. Nothing here pops; a stack shrinks with `dropLast`.
- `&&` and `||` cannot appear directly inside an `if (…)` or `loop (…)` head;
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
- A `loop (cond)` or `loop (0..n)` body is lowered to recursion on commonJS, so a
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
constructor and stamps `std/time` itself, which is what a publisher wanted
anyway. `std/time` is imported by `events.bp` (a `src/` module) and never by a
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
`{ "workspace": true }`) builds; nothing is listed. It also **runs**: `botopink run`
inside it serves `GET /api/users/` → `ana, bob, cleo`, `GET /api/users/ana` →
`Hello, ana!`, `GET /api/posts/` → `hello world | rakun rocks`,
`POST /api/posts/` → 201 `created: hi` and `GET /api/nope` → 404, which is what
its `src/main.bp` header documents. Its `main.bp` imports the whole type
closure of each module it uses (`UserController`, `UserService`,
`UserRepository`, `Request`, `Response`, …): importing a type re-checks its
declaration in the importing module, so every type its fields and method
signatures name has to be in scope there too, or the build reds with
`unknown type '<Name>'`.
