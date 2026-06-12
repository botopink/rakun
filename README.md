# rakun

[![CI](https://github.com/botopink/rakun/actions/workflows/test.yml/badge.svg?branch=feat)](https://github.com/botopink/rakun/actions/workflows/test.yml)

> Spring-style application framework for botopink — an IoC container with
> constructor dependency injection plus a declarative web layer.

`rakun` is **opt-in**, never auto-loaded: it enters a module's scope only via
`from "rakun"`. The compiler core knows nothing about rakun — every behaviour is
plain botopink + a host runtime, on the generic annotation-processor mechanism
(`@Decl` reflection, comptime decorator bodies, `@emit`).

## Install

```bp
import {service, restController, get, post, value, bean, configuration} from "rakun";
```

## Quick example

```bp
#[service]
record Greeter {}
fn (g: Greeter) hello(name: String) -> String {
    "hi, " ++ name
}

#[restController]
#[route("/api")]
record HelloController {
    val greeter: Greeter,
}
#[get("/hello/:name")]
fn (c: HelloController) hello(name: String) -> String {
    c.greeter.hello(name)
}

fn main() -> Unit {
    Rakun.run();
}
```

## What's inside

- **IoC container** — `#[service]`, `#[component]`, `#[bean]`, `#[configuration]`.
- **Scopes** — `singleton` (default), `value` (config), `bean` (factory method).
- **Web layer** — `#[restController]` + `#[get]`/`#[post]`/`#[put]`/`#[delete]`
  route annotations.
- **Real HTTP server** — node `http` module, sidecar `.mjs` shipping via
  `libs.zig`.
- **Bootstrap** — `Rakun.run()` scans the module tree, builds the DI graph,
  starts the server.

## Status

- ✅ DI container, scopes, web layer, real server, comptime route table.
- 🟡 Erlang backend server — not yet ported.

## Docs

- [AGENTS.md](AGENTS.md) — how the wiring works (singleton factories, `@emit`).
- [docs.md](docs.md) — full reference.
- [examples/](examples/) — runnable demos.

## License

Same as the parent botopink workspace.
