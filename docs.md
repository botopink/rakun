# rakun — Spring-style application framework

> Path: `repository/rakun/`
> Sibling (AGENTS): [`./AGENTS.md`](AGENTS.md)
> Parent (workspace): [`../AGENTS.md`](../AGENTS.md)
> Spec: [`../../tasks/v0.beta.5/specs/rakun.md`](../../tasks/v0.beta.5/specs/rakun.md)

`rakun` is botopink's answer to Java's **Spring** / Spring Boot: a dependency-
injection container paired with a declarative web layer, plus a real bootstrap
that starts an HTTP server. It is **opt-in** — reached via `from "rakun"` and
never auto-loaded into the type environment. **The compiler core knows nothing
about rakun** — every behaviour is plain botopink (`@Decl` reflection + comptime
decorator bodies + `@emit`) over a host runtime (`runtime.mjs`), with the HTTP
transport in the framework-agnostic `libs/server`.

## What it provides

- **HTTP layer** — `Response` with builders (`Response.ok`/`json`/`created`/
  `withStatus`/`notFound`/`badRequest`), the `HttpMethod` enum, the `App`
  bootstrap config, and the `Request` interface (`param`/`query`/`header`/`body`).
- **IoC container** — components (`#[component]`/`#[service]`/`#[repository]`/
  `#[controller]`/`#[restController]`) scanned at module load; each gets an emitted
  factory `__rkMake_<Type>()`.
- **Singleton scope** — one shared instance per component type: the factory is
  `rkSingleton("Type", { -> …construct… })`, so a 3-level chain (or a diamond)
  resolves a single repo/service instance.
- **Constructor dependency injection** — declare a dependency as a `record` field;
  rakun resolves it by type. No setter/field injection.
- **`#[configuration]` + `#[bean]`** — a `#[bean]` method's return type becomes an
  injectable singleton (an emitted `__rkMake_<ReturnType>()` calls the bean).
- **`#[value("key")]` property injection** — a `#[value]` field is filled from the
  config source (`rkProp`/`rkPropInt`), **excluded** from the DI graph.
- **Web layer** — `#[restController, route(prefix)]` + `#[getMapping(path)]`/… emit
  a route registration per method; the dispatcher matches `(verb, path)` —
  including `:name` params — and runs the handler over `Request`/`Response`, or 404s.
- **Cycle detection** — `__rkMake_X` brackets construction with `rkEnter`/`rkDone`;
  a cycle A→B→A raises at first construction (runtime — a single decorator has no
  whole-graph view).
- **Bootstrap** — `Rakun.run(App(port: 8080, basePath: "/api"))` reads the host
  router and starts `libs/server`, dispatching every live request to the handler.

## Spring → rakun mapping

| Spring | rakun |
|---|---|
| `@Component` / `@Service` / `@Repository` | `#[component]` / `#[service]` / `#[repository]` |
| `@RestController` + `@RequestMapping("/api")` | `#[restController, route("/api")]` |
| `@GetMapping("/x")` … | `#[getMapping("/x")]`, `#[postMapping]`, `#[putMapping]`, `#[patchMapping]`, `#[deleteMapping]` |
| `@Autowired` (constructor) | a `record` field — injected by type |
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
pub record GreetingService {
    pub fn greet(self: Self, name: string) -> string {
        return "Hello, " + name + "!";
    }
}

#[restController, route("/api")]
pub record GreetingController {
    greeting: GreetingService,           // injected by type

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

## Loading notes

Unlike `libs/std`, this package is **not** `@embedFile`'d into a `prelude.zig`
and is **not** wired into `build.zig`. It is an **application-level** lib reached
via `from "rakun"`, opted into per project (which also declares `server` as a
dependency, since `Rakun.run` starts it). The runtime `.mjs` files are shipped
next to the emitted modules by the CLI (**G2**), so a consumer build resolves
every `#[@external]` require.

## See also

- The embedded standard library → [`../botopink-lang/libs/std/docs.md`](../botopink-lang/libs/std/docs.md).
- The HTTP server backing → [`../botopink-lang/libs/server/docs.md`](../botopink-lang/libs/server/docs.md).
- The runnable end-to-end app → [`./examples/rakun/`](examples/rakun/).
- The `.bp` libraries group contract → [`../AGENTS.md`](../AGENTS.md).
