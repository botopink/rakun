# rakun-ssr — the full-stack joint

> Package: [`modules/rakun-ssr/`](../../modules/rakun-ssr/) · index: [`../docs.md`](../docs.md) · notes: [`../../modules/rakun-ssr/AGENTS.md`](../../modules/rakun-ssr/AGENTS.md)

rakun-ssr is the full-stack orchestrator of the botopink ecosystem: the one package that imports
rakun-bpp (the UI), rakun-stylesheet (the styles, with its bridge into rakun-bpp) and rakun (the server)
together, and wires them into an application with an `app/` convention (decision 113). rakun-bpp
and rakun never import each other, rakun-stylesheet imports nobody, and neither rakun-bpp nor rakun names
rakun-ssr: every value that crosses between them is handed across here.

**rakun-ssr is opt-in.** Nothing in `libs/std`, the shared libraries (`routing`, `actions`,
`validation`) or the compiler references it; a project that does not list it never loads it.

**Requirements.** OTP 28 or later for the server half (the release OTP the botopink CI runs;
the erlang backend's `json` and `maybe` usage needs it) — the replacement for Next's
"Node.js >= 20.9". Node 20 or later for the CLI and the client build (`rakun-ssr` is commonJS).

## Features

Each feature is a directory, `conformance/rakun-ssr/<feature>/`: its `docs.md`
says what the feature does and links the cells beside it.

| Feature | What it shows |
|---|---|
| [What rakun-ssr owns](project/docs.md) |  |
| [The four seams](seams/docs.md) |  |
| [The client bundle](client-bundle/docs.md) |  |
| [Styles and static files](styles/docs.md) |  |
| [The release](release/docs.md) |  |
| [Fonts](fonts/docs.md) |  |
| [Images](images/docs.md) |  |
| [Social cards](social-cards/docs.md) |  |
| [The commands](commands/docs.md) |  |

## What rakun-ssr deliberately does not build

| Not built | Why it is not here |
|---|---|
| `reexports.bp` | A consumer writes `import {div, text} from "rakun-bpp";` because that is where `div` lives. A re-export layer buys one shorter import line for a second name for every symbol in three libraries |
| `PageProps` / `LayoutProps` / `Params` | rakun-bpp delivers `PageContext` and `LayoutProps`, and `params` is read with `ctxParam(route, name)`. A second vocabulary is a translation layer and a class of bugs |
| `registerPage` / `registerLayout` / `registerAction` | rakun-bpp's `#[page]` / `#[layout]` decorators fill rakun-bpp's UI registry, the boot copies it into rakun's table, rakun's `#[serverAction]` registers actions, and `rakun-ssr` generates the `pub mod` lines that make the decorated modules load |
| `renderDocument` | rakun-bpp owns the document and the moments the render plugin is called, because only the render knows whether the response is streaming |
| `ActionResponse<S>(state, success, message)` | rakun's `ActionResult` (the library `actions`' envelope) is the action envelope |
| `RouteSegmentConfig(dynamic, revalidate)` | rakun front 60's `SegmentConfig(dynamic, dynamicParams, revalidate, fetchCache)` |

## What is not wired yet

`rakun-ssr dev` (the build `start` serves, with changed modules reloaded into the running node); the
public root (69-b); `RequestData`'s query and headers (rakun's page `Request` enumerates neither);
the action wire names reach rakun as `rakun.actions.field` / `.header` and nothing in rakun reads
them yet (rakun front 24); prerendering (rakun front 60).
