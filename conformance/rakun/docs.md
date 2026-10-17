# rakun — the core

> Package: [`modules/rakun/`](../../modules/rakun/) · index: [`../docs.md`](../docs.md) · notes: [`../../AGENTS.md`](../../AGENTS.md)

`rakun` is botopink's answer to Java's **Spring** / Spring Boot: a dependency-
injection container paired with a declarative web layer, plus a real bootstrap
that starts an HTTP server. It is **opt-in** — reached via `from "rakun"` and
never auto-loaded into the type environment. **The compiler core knows nothing
about rakun** — every behaviour is plain botopink (`@Decl` reflection + comptime
decorator bodies + `@emit`) over a host runtime, which also carries the HTTP
transport.

There are **two host runtimes and one contract**. `src/runtime.mjs` answers the
node row; `src/sidecars/rakun_runtime.erl` answers the erlang row with an OTP
application, a supervised table owner and ETS. Every cell in `src/runtime.bp`
carries both forms, and `test/erlang_runtime_test.bp` is one set of assertions
run on both — the port is only worth as much as that file being green twice.
See [`../../AGENTS.md`](../../AGENTS.md) § The erlang host module for the OTP shape, the
sidecar naming rule and what is still blocked.

## Features

Each feature is a directory, `conformance/rakun/<feature>/`: its `docs.md`
says what the feature does and links the cells beside it.

| Feature | What it shows |
|---|---|
| [Web layer](web/docs.md) | a controller, its routes, `Request` and `Response` |
| [Configuration](configuration/docs.md) | `#[value]`, `#[configurationProperties]`, the eight sources |
| [The request context](request-context/docs.md) | the frame, its phases, `headers()`, `cookies()`, `after()`, memoization |
| [The container](container/docs.md) | `#[managed]`, `Context`, `#[provides]`, lifecycle, events, scopes, shutdown |
| [Auto-configuration](auto-configuration/docs.md) | conditions, ordering, the report, `#[profile]` |
| [Validation](validation/docs.md) | `#[validated]`, binders, application constraints, configuration that refuses to boot |
| [SSL bundles](ssl-bundles/docs.md) | resolving, reloading and reporting PEM bundles |

## Overview

### What it provides

- **HTTP layer** — `Response` with builders (`Response.ok`/`json`/`created`/
  `withStatus`/`notFound`/`badRequest`), the `HttpMethod` enum-shaped `type`, the `App`
  bootstrap config, and the `Request` behavior (`param`/`query`/`header`/`body`).
- **IoC container** — components (`#[component]`/`#[service]`/`#[repository]`/
  `#[controller]`/`#[restController]`) scanned at module load; each gets an emitted
  factory `__rkMake_<Type>()`.
- **Singleton scope** — one shared instance per component type: the factory is
  `rkSingleton("Type", { -> …construct… })`, so a 3-level chain (or a diamond)
  resolves a single repo/service instance.
- **Constructor dependency injection** — declare a dependency as a field of the `type`;
  rakun resolves it by type. No setter/field injection.
- **`#[configuration]` + `#[bean]`** — a `#[bean]` method's return type becomes an
  injectable singleton (an emitted `__rkMake_<ReturnType>()` calls the bean).
- **`#[value("key")]` property injection** — a `#[value]` field is filled from the
  config source (`rkProp`/`rkPropInt`), **excluded** from the DI graph.
- **Web layer** — `#[restController, route(prefix)]` + `#[getMapping(path)]`/… emit
  a route registration per method; the dispatcher matches `(verb, path)` —
  including `:name` params — and runs the handler over `Request`/`Response`, or 404s.
- **File-convention routing** — `file_router.bp`: a URL that comes from where a
  file sits, over the library `routing` (`import {segment.parseSegment,
  table.parseTable, match.matchPath} from "routing";` — no dependency to declare).
  `parseSegment` decodes `blog`, `[slug]`, `[...slug]`, `[[...slug]]`,
  `(group)`, `@slot` and `_private`; `patternOf` builds the URL pattern with
  groups and slots dropped and the bracket spelling kept, and `slotOf` names the
  slot. The table is `kind|pattern|slot|verb` lines — `parseTable` / `writeTable`
  — and `matchPath` / `layoutChain` read it, one implementation compiled to both
  targets. `#[layout]`, `#[template]`, `#[page]` and `#[defaultView]` register a
  route from the app-relative directory they are given, and a page reads its
  parameters through `pageParams(route)` against the pattern its segment
  registered. Beside the decorator router, not instead of it.
- **Cycle detection** — `__rkMake_X` brackets construction with `rkEnter`/`rkDone`;
  a cycle A→B→A raises at first construction (runtime — a single decorator has no
  whole-graph view).
- **The BEAM server** — on the erlang row the same `rkServe` is a `gen_tcp`
  acceptor with `{packet, http_bin}` (no HTTP parser, no dependency outside
  `kernel`), one supervised process per connection, per-request reply headers,
  the `rakun.main.*` / `rakun.server.*` boot and tuning keys, and a
  startup-failure table that names the port, the transport or the construction
  stack before the node halts. See [`../../AGENTS.md`](../../AGENTS.md) § The server half.
- **Auto-configuration** — `#[autoConfiguration]` plus `#[conditionalOnModule]`,
  `#[conditionalOnProperty]`, `#[conditionalOnBean]`,
  `#[conditionalOnMissingBean]` and `#[profile]`: a configuration registers only
  when every condition on it holds, `#[autoConfigureBefore]`/`After` order the
  survivors through a real topological sort, and `autoConfigurationReport()`
  says what was applied, what was not and why. "Add the module, it configures
  itself." See § Auto-configuration.
- **Bootstrap** — `Rakun.run(App(port: 8080, basePath: "/api"))` reads the host
  router and starts the node `http` server (`rkServe`), dispatching every live
  request to the handler.
- **The filter chain** — a separate member, `from "rakun-service"`: one ordered list
  of entries between the socket and the route handler, with `#[filter]` and
  `#[middleware]` as its two entry points, `Next` for redirect/rewrite, CORS with
  deny-all defaults, and RFC 9457 problem details. See § The filter chain below.
- **Validation** — the library `validation` (`from "validation"`), and the only one
  that compiles for **both** rows: `#[validated]` on a record gives it the
  members `validate()` and `constraints()`, built from string comparisons,
  length checks and regex matches alone, so the server and the browser run the
  SAME predicate rather than two that are meant to agree. Thirteen constraint
  markers, an SPI for application constraints, message templates resolved from
  configuration, typed coercion of `Request`'s strings, and an RFC 9457 report.
  See § Validation below.

### Spring → rakun mapping

| Spring | rakun |
|---|---|
| `@Component` / `@Service` / `@Repository` | `#[component]` / `#[service]` / `#[repository]` |
| `@RestController` + `@RequestMapping("/api")` | `#[restController, route("/api")]` |
| `@GetMapping("/x")` … | `#[getMapping("/x")]`, `#[postMapping]`, `#[putMapping]`, `#[patchMapping]`, `#[deleteMapping]` |
| `@Autowired` (constructor) | a field of the `type` — injected by type |
| `@Configuration` + `@Bean` | `#[configuration]` + `#[bean]` |
| `@Value("server.port")` | `#[value("server.port")]` |
| `SpringApplication.run(App.class)` | `Rakun.run(App(port: 8080, basePath: "/api"))` |
| `ApplicationContext` | `Context` (`ctx.resolve<T>()`) — future, declaration-only |
| `ResponseEntity` | `Response` (`Response.ok(...)`, `Response.json(...)`) |
| `@Valid` / `@NotBlank` / `@Size` / `@Email` … | `#[validated]` + the constraint markers (the library `validation` library) — an explicit `validate<TypeName>(v)` call, not a parameter hook |

The decorators (`service`, `restController`, `route`, `getMapping`, …) are
symbols **exported by rakun** — import them at the call site before applying them
in a `#[ … ]` block. Route decorators use Spring's names (`getMapping`, …)
because `get`/`set`/`new` are reserved keyword tokens.

## Loading notes

Unlike `libs/std`, this package is **not** `@embedFile`'d into a `prelude.zig`
and is **not** wired into `build.zig`. It is an **application-level** lib reached
via `from "rakun"`, opted into per project. the repository's root
`botopink.json` is a **workspace** (decision 75): `from "rakun"` resolves to the member
`modules/rakun/` — whose `files` (`root`, `http`, `runtime`, `decorators`,
`bootstrap`, `rakun.d`, …, `ssl_bundle`) is exactly what a consumer sees — and never to the
umbrella, which ships nothing. A sibling member or an example inside the
workspace depends on it with `{ "rakun": { "workspace": true } }`; a project
elsewhere in the ecosystem with `{ "path": "…/modules/rakun" }`; a consumer
outside it with the git form (`{ "git": …, "branch": "feat" }`) — the object
form is the only one (decision 76). rakun has no library dependencies:
the HTTP transport `Rakun.run` starts is its own `runtime.mjs` `serve`, over node's
`http` module (commonJS only). The runtime `.mjs` files are shipped
next to the emitted modules by the CLI (**G2**), so a consumer build resolves
every `#[@External.Node]` require.

## See also

- The embedded standard library → botopink-lang's `libs/std/docs.md`.
- The runnable end-to-end app → [`examples/rakun/`](../../examples/rakun/).
- The `.bp` libraries group contract → the meta repository's `AGENTS.md`.
