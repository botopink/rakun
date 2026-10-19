# Decision 363 — A browser-only cell is `#[clientOnly]`: called only where the client runs, never given a server twin.

The example has one host cell that exists only in the browser, `linkStatus`, bound for
JavaScript alone (`#[compiler.external(.JavaScript(…))]`, no erlang twin). It is reached only
through the `#[clientOnly]` hook `status`, and that hook is used only inside `LikeButton`, a
`#[client]` component. So the server build (erlang) never emits `LikeButton`'s client half nor the
cell: on the server the island renders its fallback, and the cell runs once the browser hydrates
it.

Had `Header` — a component the server renders — written `use status()`, the build would refuse it
at the `use`: a `#[clientOnly]` hook outside a `#[client]` component. Nothing answers the server's
"empty truth" in its place; the old erlang sidecars that did are gone.

`NavLink` shows the server-rendered half: a `Link` reads no hook for its pending state. The client
router sets `data-jh-pending` on the active link and a CSS rule styles it, so no island is made per
link. `main` renders the page on the server and prints the markup.

Proving cells: `conformance/rakun-bpp/client-boundary/client_marker` (a `#[client]` component
rendering its first pass on the server). None of this repository shows a `#[clientOnly]` hook or
its refusal yet; they come with `05-jhonstart/27` steps 1–3.

[draft/main.bp](draft/main.bp)
