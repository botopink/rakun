# rakun-ssr

> The Next.js-style orchestrator for botopink: the one package that knows rakun (the server),
> rakun-bpp (the UI) and emilia (the styles) together, and wires them into an application.

**Status: in progress.** The core (`modules/rakun-ssr/`, front 49) and the core helpers of
`modules/rakun-ssr/` are written; the other members land with their track-E fronts of 1.0.10-beta.
[`conformance/docs.md`](conformance/docs.md) is the reference: the configuration, the alias map, the four seams, and what
rakun-ssr deliberately does not build.

This repository took the name `rakun-ssr` from the old mocking library (decision 79 of 1.0.10-beta):
that library is archived under the tag `mocking-lib-final`, and its surface is std's
`testing.mocks` and `testing.asserts` (`import {testing: {mocks, asserts}} from "std"`).

## Layout

`botopink.json` is a **workspace** (`"workspaces": ["modules/*", "examples/*"]`, decision 75): it
compiles nothing and ships nothing. Each member is reached by its manifest name:

| Member | `from` | Target | Front |
|---|---|---|---|
| [`modules/rakun-ssr/`](modules/rakun-ssr/) | `"rakun-ssr"` — config, project vocabulary, alias map, env rule, the boot's rakun-bpp half | both | 49 |
| [`modules/rakun-ssr/`](modules/rakun-ssr/) | `"rakun-ssr"` — `Onze.run`, the boot's rakun half | erlang | 49 |
| [`modules/rakun-ssr/`](modules/rakun-ssr/) | `"rakun-ssr"` — `assert<Subject>(loc, …)` helpers, fixtures, the E2E runner | both | 49 + each front |
| [`modules/rakun-ssr/`](modules/rakun-ssr/) | `"rakun-ssr"` — `create · dev · build · start · info` | commonJS | 50 |
| [`modules/rakun-ssr/`](modules/rakun-ssr/) | `"rakun-ssr"` — client graph, refusals, chunks, manifest, hydration entry | both | 68 |
| [`modules/rakun-ssr/`](modules/rakun-ssr/) | `"rakun-ssr"` — CSS modules, stylesheet, `public/`, `Image`, fonts | both | 69 · 51 · 52 |
| [`modules/rakun-ssr/`](modules/rakun-ssr/) | `"rakun-ssr"` — `ImageResponse` | erlang | 70 |
| [`modules/rakun-ssr/`](modules/rakun-ssr/) | `"rakun-ssr"` — build id, OTP release, Dockerfile, static export | both | 71 |

`botopink test` runs inside a member, never at the root.

A member lists the packages it imports; their own dependencies load transitively (decision 143).
The cut and the dependency graph are
`specs/06-onze/modules.md` in the botopink meta repository.
