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
over the annotated record. It `@emit`s, at the application site, (1) a scan
self-registration and (2) a SINGLETON factory `__rkMake_<Type>()` that constructs
the record once (`rkSingleton`) and caches it, injecting each field by its own
factory — except a `#[value("key")]` field, filled from config (`rkProp`/
`rkPropInt`) and kept OFF the DI graph. A controller additionally `@emit`s one
route registration per mapped method (reading `decl.methods` + the `#[route]`
prefix); a `#[configuration]` `@emit`s a `__rkMake_<ReturnType>()` per `#[bean]`
method. botopink has no top-level mutable state, so the registries those calls
feed — the scan list, the singleton cache, the cycle guard, the config props, the
router table — live in `runtime.mjs`, reached through the `#[@external]`
declarations in `runtime.bp`. The emitted code references those runtime fns by
name, so a module declaring components also imports them (`import {service,
rkScan, rkSingleton, rkEnter, rkDone, rkRegisterRoute, …} from "rakun"`). The HTTP
value types + the `Request` interface are real emitted code (`http.bp`);
`Rakun.run` (`bootstrap.bp`) starts the framework-agnostic `libs/server`.

## Tree

```text
rakun/
├── AGENTS.md          ← you are here
├── docs.md            ← what this lib provides + Spring mapping + loading notes
├── botopink.json      ← package metadata (dependencies: [server]; files: http ·
│                        runtime · decorators · bootstrap · rakun.d)
├── src/
│   ├── root.bp        ← module-tree root: `pub mod decorators; http; runtime; bootstrap;`
│   ├── http.bp        ← concrete, emitted: `HttpMethod` enum · `Response` record
│   │                    (builders) · `App` config · `Request` interface
│   ├── runtime.mjs    ← host runtime: the mutable seams (scan list · singleton cache ·
│   │                    cycle guard · config props · router table + dispatch/dispatchHttp)
│   ├── runtime.bp     ← `#[@external]` decls binding the `runtime.mjs` seams
│   │                    (`rkScan`/`rkSingleton`/`rkEnter`/`rkDone`/`rkProp`/
│   │                    `rkRegisterRoute`/`rkDispatch`/`rkDispatchHttp`/…); sibling
│   │                    `./runtime.mjs` shipped next to the emitted module (G2)
│   ├── decorators.bp  ← the markers AS comptime decorator fns: placement rules +
│   │                    the DI/router/scope/bean wiring they `@emit`
│   ├── bootstrap.bp   ← `Rakun` (concrete record): `Rakun.run(app)` starts `libs/server`
│   └── rakun.d.bp     ← declaration-only: the `Context` IoC interface (future)
└── test/
    ├── di_test.bp     ← placement + component scan
    ├── router_test.bp ← DI chain + router dispatch (200 / 404) end to end
    ├── scopes_test.bp ← singleton scope (diamond) · `#[value]` · `#[bean]` (F2-scopes)
    ├── server_test.bp ← the live HTTP dispatch pipeline (`rkDispatchHttp`): path
    │                     param · query/header/body · 200/404 (F5)
    └── overlapping_routes_test.bp ← two controllers sharing a path prefix both
                          register; dispatch matches the FULL path; a leaf (no-dep)
                          #[service] resolves through the DI chain
```

## Module tree (`root.bp`)

`src/root.bp` is the explicit module-tree root — the package builds from it, not
a deprecated blind `src/` scan. It declares the four compiled modules
`pub mod decorators; pub mod http; pub mod runtime; pub mod bootstrap;` (all
public surface, reached via `from "rakun"`; the `@emit`ted wiring imports the
runtime fns by name). The declaration module `rakun.d.bp` (the future `Context`
interface) is **not** in the tree: it is wired through `botopink.json` `files`.
`.d.bp` modules are not resolved by `mod` paths (the resolver follows only
`<name>.bp` / `<name>/mod.bp`), mirroring how `libs/std` keeps its ambient `.d.bp`
out of `root.bp`. rakun declares `server` as a **dependency** (`Rakun.run` starts
it); the consumer declares both.

## Design at a glance

- **IoC container** — components (`#[component]`/`#[service]`/`#[repository]`/
  `#[controller]`/`#[restController]`) are scanned at module load; each gets an
  emitted **singleton** factory `__rkMake_<Type>()` (`rkSingleton` — one instance
  per type, shared across a 3-level chain / diamond).
- **Constructor injection** — a dependency is declared as a `record` field and
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
  reads the router back and starts `libs/server`, dispatching each live request via
  `rkDispatchHttp`. The runtime `.mjs` files ship next to the emitted modules (G2).

## Conventions

- **`.bp` over `.d.bp`.** Logic lands in real emitted `.bp` (`http.bp` incl. the
  `Request` interface, `runtime.bp`'s `declare fn`s, `decorators.bp` bodies,
  `bootstrap.bp`). Only the future `Context` interface stays declaration-only in
  `rakun.d.bp`. `Request.param`/`query`/`header` return a plain `string` (`""` when
  absent), not `?string` — interface-method optional returns don't yet get the
  `@Option` lowering, and a required path var / empty default is the cleaner contract.
- **Host state behind `#[@external]`.** The one mutable seam is `runtime.mjs`; the
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
- The HTTP server backing `Rakun.run` starts → [`../botopink-lang/libs/server/AGENTS.md`](../botopink-lang/libs/server/AGENTS.md).

## CI

`.github/workflows/test.yml` runs `zig build test-libs -- --lib rakun
--target <t>` for `{commonJS, erlang, beam}` on `ubuntu-22.04` +
`macos-14`, plus `commonJS` on `windows-2022`. No `wasm` cell —
rakun's server surface targets node + the BEAM. `BOTOPINK_LANG_REF`
repo variable pins a specific botopink-lang ref (default `main`).

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
