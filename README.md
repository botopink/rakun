# rakun

[![CI](https://github.com/botopink/rakun/actions/workflows/test.yml/badge.svg?branch=feat)](https://github.com/botopink/rakun/actions/workflows/test.yml)

> Spring-style application framework for botopink — an IoC container with
> constructor dependency injection plus a declarative web layer.

`rakun` is **opt-in**, never auto-loaded: it enters a module's scope only via
`from "rakun"`. The compiler core knows nothing about rakun — every behaviour is
plain botopink + a host runtime, on the generic annotation-processor mechanism
(the declaration handle read through `compiler.*`, comptime decorator bodies, `compiler.compile`).

## Install

Inside the botopink ecosystem a project depends on the core member by path or, as a sibling
member of this workspace, with `{ "workspace": true }`; outside it, on the git form after a release:

```json
"dependencies": { "rakun": { "git": "https://github.com/botopink/rakun.git", "branch": "feat" } }
```

```bp
import {service, restController, getMapping, postMapping, value, bean, configuration} from "rakun";
```

## The CLI

`modules/rakun-cli` (front 88) is the server CLI: `rakun new <name> [--template
plain|full-stack|library]`, `rakun run [--profile] [--port] [--watch]`, `rakun build` (an OTP
release), `rakun test`, and `rakun routes` / `rakun beans` / `rakun config`, which inspect a project
without starting it; `rakun help` lists them and any `#[cliCommand]` a project adds. Exit codes: 0
done, 1 failed, 2 usage, 3 does not compile. A full-stack project uses rakun-ssr's CLI (`rakun-ssr dev`).

## Layout

`botopink.json` at the root is a **workspace** (`"workspaces"`: `modules/*`, `examples/*` and one
`examples/<package>/*` per package, decision 75 of 1.0.10-beta): it compiles nothing and ships nothing. The core is
the member [`modules/rakun/`](modules/rakun/) — `from "rakun"` resolves to it — beside the other packages of
[`modules/`](modules/README.md): `rakun-service`, `rakun-data`, `rakun-security`, … for the server side,
`rakun-style`, `rakun-bpp` (the `.bpp` components, the render, the forms) and `rakun-stylesheet` for the UI side,
and `rakun-ssr` (the `rakun-ssr create|build|start` command line and the Next-style orchestrator) on top. Adding a
package to a program's `botopink.json` is all it takes; `examples/` shows the combinations. `botopink test` runs
inside a member, never at the root.

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

fn main() -> void {
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

- [AGENTS.md](AGENTS.md) — how the wiring works (singleton factories, `compiler.compile`).
- [conformance/docs.md](conformance/docs.md) — full reference; every example is a checked cell in [conformance/rakun/](conformance/rakun/).
- [examples/](examples/) — runnable demos.

## License

MIT — see [`LICENSE`](LICENSE). Same license as the rest of the botopink workspace.
