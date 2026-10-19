# Decision 186 — The stage a page renders in is a compile-time fact.

Three hooks and two pages. `sortOrder` reads `use searchParams()` and is marked `#[serverOnly]`: it may run only on the server at request time. `viewportWidth` is marked `#[clientOnly]` and is used only inside `#[client] SizeBadge`, the one place it is legal. `greeting` carries no marker and may run at any stage. The compiler reads each page's `use`s at build: `about` reaches only `greeting`, so it is prerendered — rendered once at the build — and the build writes its route kind `S`; `search` reaches `sortOrder`, so it is rendered per request and its kind is `D`. rakun reads those kinds from the build; nothing marks a page dynamic at run time. `main` renders the two pages as the server would and prints them.

Each misuse is refused at the `use`, at build: `use sortOrder()` inside `SizeBadge` (a server-only hook in a client component), `use viewportWidth()` in `about` (a client-only hook outside one), and `use sortOrder()` in a page that declares itself prerendered.

Cells of this repository that prove it: none yet. `rakun-bpp/router/router_hooks` reads the router hooks with no marker; the markers and the build-written kinds come with `05-jhonstart/26` step 8, `07-onze/49` step 5 and `04-rakun/22` step 4, over the checker capability of 277.

[draft/main.bp](draft/main.bp)
