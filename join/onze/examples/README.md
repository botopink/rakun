# onze examples

Every child of `examples/` holding a `botopink.json` is a member of the onze workspace and a row
of `zig build test-libs`. `blog/` exists (front 53: the store, the read path, the boundaries, the
dashboard's gate, a client island — built by `onze build` and served by `onze start`) and
`scaffold/` (front 50: what `onze create scaffold --yes --libs ../../..` writes, diffed against a
fresh `create` by `modules/onze-cli/test/create_test.bp`); `static-site/` arrives with front 71. The three projects
(`specs/1.0.10-beta/06-onze/modules.md` § `repository/onze/examples/**`):

| Example | Front | What it proves |
|---|---|---|
| `blog/` | 53 | the acceptance app — every route under `onze dev` and `onze build && onze start`, the client chunk, the stylesheet, the OG route, the release |
| `scaffold/` | 50 | the committed output of `onze create scaffold --yes` |
| `static-site/` | 71 · 60 | `output: export` — every route prerenderable |

`blog/` keeps its sources under `src/` (`src/app/`, `src/components/`, `src/lib/` — `onze.json`'s
`appDir` is `"src/app"`, Next's `src/` layout, decision pending 53-a); `scaffold/` is the root
layout `onze create` writes by default (`"src": "."`).
