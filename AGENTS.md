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
│   │   │   ├── bootstrap.bp   ← `Rakun` (concrete type): `Rakun.run(app)` starts `rkServe`
│   │   │   └── rakun.d.bp     ← declaration-only: the `Context` IoC behavior (future)
│   │   └── test/
│   │       ├── di_test.bp     ← placement + component scan
│   │       ├── router_test.bp ← DI chain + router dispatch (200 / 404) end to end
│   │       ├── scopes_test.bp ← singleton scope (diamond) · `#[value]` · `#[bean]` (F2-scopes)
│   │       ├── server_test.bp ← the live HTTP dispatch pipeline (`rkDispatchHttp`): path
│   │       │                     param · query/header/body · 200/404 (F5)
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
