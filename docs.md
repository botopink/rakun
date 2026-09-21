# rakun — Spring-style application framework

> Path: `repository/rakun/` (a workspace) · core: `repository/rakun/modules/rakun/`
> Sibling (AGENTS): [`./AGENTS.md`](AGENTS.md) · Members: [`./modules/README.md`](modules/README.md)
> Parent (workspace): [`../AGENTS.md`](../AGENTS.md)
> Spec: [`../../tasks/v0.beta.5/specs/rakun.md`](../../tasks/v0.beta.5/specs/rakun.md)

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
See [`./AGENTS.md`](AGENTS.md) § The erlang host module for the OTP shape, the
sidecar naming rule and what is still blocked.

## What it provides

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
  file sits. `parseSegment` decodes `blog`, `[slug]`, `[...slug]`, `[[...slug]]`,
  `(group)`, `@slot` and `_private`; `patternOf` builds the URL pattern with
  groups and slots dropped and the bracket spelling kept, and `slotOf` names the
  slot. Beside the decorator router, not instead of it.
- **Cycle detection** — `__rkMake_X` brackets construction with `rkEnter`/`rkDone`;
  a cycle A→B→A raises at first construction (runtime — a single decorator has no
  whole-graph view).
- **The BEAM server** — on the erlang row the same `rkServe` is a `gen_tcp`
  acceptor with `{packet, http_bin}` (no HTTP parser, no dependency outside
  `kernel`), one supervised process per connection, per-request reply headers,
  the `rakun.main.*` / `rakun.server.*` boot and tuning keys, and a
  startup-failure table that names the port, the transport or the construction
  stack before the node halts. See [`./AGENTS.md`](AGENTS.md) § The server half.
- **Bootstrap** — `Rakun.run(App(port: 8080, basePath: "/api"))` reads the host
  router and starts the node `http` server (`rkServe`), dispatching every live
  request to the handler.

## Spring → rakun mapping

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

The decorators (`service`, `restController`, `route`, `getMapping`, …) are
symbols **exported by rakun** — import them at the call site before applying them
in a `#[ … ]` block. Route decorators use Spring's names (`getMapping`, …)
because `get`/`set`/`new` are reserved keyword tokens.

## Usage

```bp
import {Rakun, App, Request, Response} from "rakun";
import {service, restController, route, getMapping} from "rakun";
import {rkScan, rkSingleton, rkEnter, rkDone, rkRegisterRoute} from "rakun";

#[service]
pub type GreetingService {
    pub fn greet(self: Self, name: string) -> string {
        return "Hello, " + name + "!";
    }
}

#[restController]
#[route("/api")]
pub type GreetingController(
    // injected by type
    greeting: GreetingService,
) {
    #[getMapping("/hello/:name")]
    pub fn hello(self: Self, req: Request) -> Response {
        return Response.ok(self.greeting.greet(req.param("name")));
    }
}

fn main() {
    Rakun.run(App(port: 8080, basePath: "/api"));
}
```

`Request.param`/`query`/`header` return a plain `string` (`""` when absent) — a
matched route's path params are always present, and `""` is the natural default
for a missing query/header (Spring's `@RequestParam(defaultValue = "")`).

The emitted DI/router wiring calls the host runtime by name, so a module
declaring components imports those fns too (`rkScan`/`rkSingleton`/`rkEnter`/
`rkDone`/`rkRegisterRoute`; add `rkProp`/`rkPropInt` when it has a `#[value]`
field). See the runnable end-to-end app under
[`./examples/rakun/`](examples/rakun/).

## Configuration

`#[value("key")]` reads the property table; `config.bp` fills it. A whole record
binds at once with `#[configurationProperties]`:

```bp
#[configurationProperties("my.service")]
pub type MyService(
    enabled: bool,
    remoteAddress: string,                       // binds from remote-address too
    #[unit("seconds")] sessionTimeout: Duration,
    #[nested] security: Security,
)
```

The record is then injectable by type into any `#[service]`, and every key it
declares lands in the run-time catalogue.

```bp
import {readDocument, rkConfigApply, entryAt} from "rakun";

val docs = try readDocument("application.yaml");
loop (docs) { d -> val _ = rkConfigApply(d.entries); };
```

`rkConfigLoad()` is the whole load: eight sources in order (command line,
`RAKUN_APPLICATION_JSON`, environment, profile documents, base documents,
configuration trees, `rkSetProp`, declared defaults), profiles resolved and
written to `rakun.profiles.resolved`, and one refusal naming the input when a
location, an import, a document or a profile group is wrong.

```bp
import {rkConfigLoad} from "rakun";
import {active} from "rakun";

fn main() {
    try rkConfigLoad();
    @print(active().join(","));
}
```

`${key}` and `${key:default}` resolve at load time; `${random.uuid}`,
`${random.int[1024,65536]}` and friends resolve per REFERENCE through
`rkValue(key)`. Typed readers — `rkPropBool`, `rkPropIntOr`, `rkPropFloat`,
`rkPropList`, `rkPropDuration`, `rkPropSize` — carry the declared default as
their second argument and try the kebab, camel and `SCREAMING_SNAKE` spellings
of a key before giving up.

Three formats are read — `.properties`, `.json` and a documented YAML subset —
plus `configtree:` directories (one file per key). A nested JSON object flattens
to dot keys (`server.port`) and an array to indexed keys (`a[0]`). A YAML
construct outside the subset (anchor, alias, flow style, block scalar, tag) is a
located refusal naming the file and the line, never a silent mis-parse. See
[`AGENTS.md`](AGENTS.md) § Externalized configuration for the table.

## Loading notes

Unlike `libs/std`, this package is **not** `@embedFile`'d into a `prelude.zig`
and is **not** wired into `build.zig`. It is an **application-level** lib reached
via `from "rakun"`, opted into per project. `repository/rakun/botopink.json` is a
**workspace** (decision 75): `from "rakun"` resolves to the member
`modules/rakun/` — whose `files` (`root`, `http`, `runtime`, `decorators`,
`bootstrap`, `rakun.d`) is exactly what a consumer sees — and never to the
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

- The embedded standard library → [`../botopink-lang/libs/std/docs.md`](../botopink-lang/libs/std/docs.md).
- The runnable end-to-end app → [`./examples/rakun/`](examples/rakun/).
- The `.bp` libraries group contract → [`../AGENTS.md`](../AGENTS.md).
