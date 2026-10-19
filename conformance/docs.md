# rakun — the workspace's reference

> Repository: [`../AGENTS.md`](../AGENTS.md) · packages: [`../modules/README.md`](../modules/README.md)

`botopink/rakun` is one workspace of packages (`modules/<package>/`). This
directory is its reference and the programs that prove it: every package that
has a reference keeps its map in `conformance/<package>/docs.md` and one
`docs.md` per feature in `conformance/<package>/<feature>/`; every program a
feature shows is a cell beside its text — `conformance/<package>/<feature>/<cell>/`
(decision 548).

## The packages

One entry per package, in the order of `modules/rakun/src/version_set.bp`. A
package with no reference yet has no row of features.

| Package | Reference | Features (cells under `conformance/<package>/`) |
|---|---|---|
| `rakun` | [rakun/docs.md](rakun/docs.md) | web layer `web/` · configuration `configuration/` · the request context `request-context/` · the container `container/` · auto-configuration `auto-configuration/` · validation `validation/` · SSL bundles `ssl-bundles/` |
| `rakun-app` | [rakun-app/docs.md](rakun-app/docs.md) | file-convention routing `file-routing/` · server-side rendering `ssr/` (no cells yet) |
| `rakun-bpp` | [rakun-bpp/docs.md](rakun-bpp/docs.md) | components `components/` · hooks `hooks/` · the `html` DSL `html-dsl/` · the router `router/` · server components `server-components/` · client navigation `client-navigation/` · the client boundary `client-boundary/` · render and streaming `streaming/` · forms `forms/` · error boundaries `error-boundaries/` · metadata `metadata/` |
| `rakun-cache` | — | |
| `rakun-cli` | — | |
| `rakun-data` | — | |
| `rakun-mail` | — | |
| `rakun-messaging` | — | |
| `rakun-metrics` | — | |
| `rakun-restclient` | — | |
| `rakun-scheduling` | — | |
| `rakun-security` | — | |
| `rakun-service` | [rakun-service/docs.md](rakun-service/docs.md) | the filter chain `filter-chain/` · TLS on the web layer `tls/` |
| `rakun-session` | — | |
| `rakun-ssr` | [rakun-ssr/docs.md](rakun-ssr/docs.md) | what it owns `project/` · the four seams `seams/` · the client bundle `client-bundle/` · styles `styles/` · the release `release/` · fonts `fonts/` · images `images/` · social cards `social-cards/` · the commands `commands/` (no cells yet) |
| `rakun-style` | — | |
| `rakun-stylesheet` | [rakun-stylesheet/docs.md](rakun-stylesheet/docs.md) | getting started `getting-started/` · the reset `reset/` · container queries `containers/` · escape hatches `escape-hatches/` · typography `typography/` · colour `color/` · spacing `spacing/` · sizing `sizing/` · layout `layout/` · borders `borders/` · effects `effects/` · motion `motion/` · modifiers `modifiers/` · the theme `theme/` · the runtime and the output `output/` |
| `rakun-websocket` | — | |
| `jhonstart-dom-test` | — | |
| `onze-server` | — | |

## The decisions

| Directory | What |
|---|---|
| `modules/decisions-taken/` | The ledger's index: one `<slug>-<N>/` per code-bearing row of this repository's generated [`../decisions-taken.md`](../decisions-taken.md) (front 166, decisions 646–651), its `docs.md` walking through one example program; in phase 1 the program is `draft/main.bp` (decision 649), so `botopink cell check conformance/` finds no cell there. The decision cells are the ledger's, not a package's feature: they sit outside the package tree, and `modules/botopink.json` is the workspace `scripts/decision-cells.py compile` reads for their dependencies |

## The suite

```text
conformance/
├── docs.md                       this index
└── <package>/
    ├── docs.md                   the package's map: one line per feature, and the text no feature owns
    └── <feature>/
        ├── botopink.json         the feature's workspace: its cells are its members ("*")
        ├── docs.md               what the feature does, linking the cells beside it: {<cell>/src/main.bp}
        └── <cell>/
            ├── botopink.json     the cell's name, and what it adds (a "targets" narrowing, its own deps/)
            ├── docs.md           the reference text the cell shows, and {src/main.bp}
            ├── src/main.bp       the program
            └── snapshot/         what it answers (output/, targets/<t>/)
```

`conformance/botopink.json` declares what every cell shares — the targets and
the version — and lists each feature's cells (`"<package>/<feature>/*"`); the
cells' dependencies share one code cache under `conformance/.botopinkbuild/`.
Each cell declares the package it consumes
(`../../../../modules/<package>`), never the root: a workspace's dependencies
reach every member, and a commonJS cell must not load `rakun`. A cell that
runs on fewer targets narrows `"targets"` in its own `botopink.json` (the
`rakun` and `rakun-service` cells: erlang and beam), and a cell that needs a
package the root does not declare keeps it in its own `deps/` (the
`rakun-service` cells).

`botopink cell check conformance/` checks every cell; `scripts/gate.sh` runs it
as the gate's conformance stage.

## Code is linked, never copied

A reference shows a program by naming its file: a path in braces, relative to
the directory of the `docs.md` that holds it, is the file to show —
`{src/main.bp}` in a cell's `docs.md`, `{<cell>/src/main.bp}` in a feature's. A
`docs.md` links into its own folder or one level down; the package's map links
its features' `docs.md` with ordinary markdown links. A fence in a
reference is never a program: a grammar, a table, a layout, a configuration
file or an output is fenced as `text` (or its own format); a program is a cell.
`scripts/check-doc-links.sh` fails when a link names no file, when a cell's
`docs.md` does not link `{src/main.bp}`, when no feature `docs.md` links a
cell, or when a ```` ```bp ```` fence remains.
