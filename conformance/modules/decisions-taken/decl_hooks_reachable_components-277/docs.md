# Decision 277 — The shape of 186's checker capability.

`pages` holds a page and the components it reaches, all built with rakun-bpp's elements: `Page` renders `UserMenu`, which renders `Avatar`, `Counter` and `Avatar` again; `Counter` holds a `use state(3)`. The program's own decorator `#[graph]` reads `compiler.hooks(decl)` on `Page` and records one line per node. The list holds every function reachable through calls of components, `Page` first, breadth-first in body order, each function once — `Page`, `UserMenu`, `Avatar`, `Counter` — each node with only what is written in it: `Counter`'s one `use` of `state`, `UserMenu`'s three calls in order, `Avatar` listed once although called twice. `main` reads the record at build from another module (a decorator that reads the hooks runs after its module's bodies) and prints it, then renders the page: `<div><div><p>avatar</p><p>3</p><p>avatar</p></div></div>`.

The compiler names no stage, marker or library: a library declares its own markers (`#[serverOnly]`, `#[clientOnly]`) and its `#[page]` / `#[client]` read this list against them, so a page reaching a `#[serverOnly]` from a `#[client]` is refused with every path reported.

Cells of this repository that prove it: none yet. rakun-bpp's `#[page]` and `#[client]` (`modules/rakun-bpp/src/routes.bp`, `client.bp`) read the return type only, and `serverOnly` is an import marker, not a decorator; the walk over the hooks is `05-jhonstart/26` step 8's and `04-rakun/22` step 4's.

[draft/main.bp](draft/main.bp)

[draft/pages.bp](draft/pages.bp)
