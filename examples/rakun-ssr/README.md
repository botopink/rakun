# rakun-ssr examples

Every child of `examples/rakun-ssr/` holding a `botopink.json` is a member of the rakun workspace (`examples/rakun-ssr/*`)
and a build of the gate. `blog/` exists (front 53: the store, the read path, the boundaries, the
dashboard's gate, a client island — built by `rakun-ssr build` and served by `rakun-ssr start`) and
`scaffold/` (front 50: what `rakun-ssr create scaffold --yes --libs ../../..` writes (`--libs` is a rakun checkout), diffed against a
fresh `create` by `modules/rakun-ssr/test/cli/create_test.bp`); `static-site/` arrives with front 71. The three projects
(the former onze repository's `examples/**`):

| Example | Front | What it proves |
|---|---|---|
| `blog/` | 53 | the acceptance app — every route under `rakun-ssr dev` and `rakun-ssr build && rakun-ssr start`, the client chunk, the stylesheet, the OG route, the release |
| `scaffold/` | 50 | the committed output of `rakun-ssr create scaffold --yes` |
| `static-site/` | 71 · 60 | `output: export` — every route prerenderable |

`blog/` keeps its sources under `src/` (`src/app/`, `src/components/`, `src/lib/` — `rakun-ssr.json`'s
`appDir` is `"src/app"`, Next's `src/` layout, decision pending 53-a); `scaffold/` is the root
layout `rakun-ssr create` writes by default (`"src": "."`).
