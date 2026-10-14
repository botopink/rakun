# jhonstart

[![CI](https://github.com/botopink/jhonstart/actions/workflows/test.yml/badge.svg?branch=feat)](https://github.com/botopink/jhonstart/actions/workflows/test.yml)

> React/Next-style UI framework written in botopink — on the language's own
> primitives. No compiler-core support; reached via `from "jhonstart"`.

Components are functions returning `@Component<Element>`; hooks are nouns
(`state`, `memo`, `router` — no `use` prefix) returning the `@Component<_>`
capability, activated by the `use` keyword; a server component that only loads data
is `fn … -> @Task<Element>` — the return type is the effect, there is no annotation
(botopink decisions 118–128). A component returns `Element`, not a `@Result`, so it
handles a failed load in its own body (`try await load() catch …`, `case`);
the JSX-like `html """…"""` DSL reuses `expr-templates` (`@Expr<Element>`),
expanding markup to the builder pipeline at comptime.

## Install

```json
"dependencies": { "jhonstart": { "git": "https://github.com/botopink/jhonstart.git", "branch": "feat" } }
```

```bp
import {div, p, text, state, effect, renderToString} from "jhonstart";
import {html} from "jhonstart-html";   // the markup DSL, its own member
import {Link, linkProps} from "jhonstart-link";   // client navigation, its own member
```

## Layout

`repository/jhonstart/botopink.json` is a **workspace** (`"workspaces": ["modules/*", "examples/*"]`,
decision 75 of 1.0.10-beta): it compiles nothing and ships nothing. The library is the member
[`modules/jhonstart/`](modules/jhonstart/) — `from "jhonstart"` resolves to it — beside
[`modules/jhonstart-html/`](modules/jhonstart-html/) (`from "jhonstart-html"`: the `html """…"""` DSL),
[`modules/jhonstart-link/`](modules/jhonstart-link/) (`from "jhonstart-link"`: `Link` and the remount decision),
[`modules/jhonstart-test/`](modules/jhonstart-test/) (the test-helper member: `assert<Subject>` snapshot
helpers, fixtures and the render harness) and the runnable examples [`examples/jhonstart-counter/`](examples/jhonstart-counter/),
[`examples/jhonstart-markup/`](examples/jhonstart-markup/),
[`examples/jhonstart-todo/`](examples/jhonstart-todo/), [`examples/blog-ssr/`](examples/blog-ssr/),
[`examples/nav-shell/`](examples/nav-shell/), [`examples/islands/`](examples/islands/),
[`examples/forms/`](examples/forms/) and [`examples/document-shell/`](examples/document-shell/),
each depending on its members with `{ "<member>": { "workspace": true } }`. `botopink test` runs inside a member, never at the root.

## Quick example

```bp
import {ElementBase, div, p, text, state, renderToString} from "jhonstart";

fn Counter() -> @Component<Element> {
    val c = use state(0);
    return div([
        p([text("count: " + c.value.toString(), [])], []),
    ], []);
}

fn main() -> @Task<void> {
    @print(renderToString(await Counter()));
}
```

## Status

- ✅ `Element` tree + builders + synchronous `renderToString`.
- ✅ Hook family (`state`, `effect`, `memo`, `ref`, `reducer`) — pure server-pass
  bodies, plus `modules/jhonstart/src/client_runtime.mjs` with the same nouns
  over a re-render loop for the client build.
- ✅ `html """…"""` comptime expander (real `.bp`, single-pass).
- 🟡 Router + Http server context: still declarative (`.d.bp`), each gated on a
  generic language gap.

See [AGENTS.md](AGENTS.md) for the architectural status notes.

## Docs

- [AGENTS.md](AGENTS.md) — architecture, conventions, the "no compiler-core
  coupling" rule.
- [conformance/docs.md](conformance/docs.md) — full reference.
- [examples/](examples/) — runnable demos (counter, todo, blog).

## License

MIT — see [`LICENSE`](LICENSE). Same license as the rest of the botopink workspace.
