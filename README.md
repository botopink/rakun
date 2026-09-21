# rakun

[![CI](https://github.com/botopink/rakun/actions/workflows/test.yml/badge.svg?branch=feat)](https://github.com/botopink/rakun/actions/workflows/test.yml)

> Spring-style application framework for botopink — an IoC container with
> constructor dependency injection plus a declarative web layer.

`rakun` is **opt-in**, never auto-loaded: it enters a module's scope only via
`from "rakun"`. The compiler core knows nothing about rakun — every behaviour is
plain botopink + a host runtime, on the generic annotation-processor mechanism
(`@Decl` reflection, comptime decorator bodies, `@emit`).

## Install

Inside the botopink ecosystem a project depends on the core member by path or, as a sibling
member of this workspace, with `{ "workspace": true }`; outside it, on the git form after a release:

```json
"dependencies": { "rakun": { "git": "https://github.com/botopink/rakun.git", "branch": "feat" } }
```

```bp
import {service, restController, getMapping, postMapping, value, bean, configuration} from "rakun";
```

## Layout

`repository/rakun/botopink.json` is a **workspace** (`"workspaces": ["modules/*", "examples/*"]`,
decision 75 of 1.0.10-beta): it compiles nothing and ships nothing. The core is the member
[`modules/rakun/`](modules/rakun/) — `from "rakun"` resolves to it — beside one member per Spring
Boot starter under [`modules/`](modules/README.md) (`rakun-web`, `rakun-data`, `rakun-security`, …,
thirteen scaffolds today, thirteen more planned) and the runnable example
[`examples/rakun/`](examples/rakun/) (member `rakun-example`). `botopink test` runs inside a member,
never at the root.

## Quick example

```bp
import {service, restController, get, route} from "rakun";

#[service]
pub type Greeter {
    pub fn hello(self: Self, name: string) -> string {
        return "hi, " + name;
    }
}

#[restController]
#[route("/api")]
pub type HelloController(
    greeter: Greeter,
) {
    #[get("/hello/:name")]
    pub fn hello(self: Self, name: string) -> string {
        return self.greeter.hello(name);
    }
}

fn main() {
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

MIT — see [`LICENSE`](LICENSE). Same license as the rest of the botopink workspace.
