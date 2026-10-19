# Decision 46 — `d["k"]` on a `Dict` routes to `lookup`

A tiny route table: a `Dict<string, Response>` of rakun responses keyed by path. `serve` reads it with the index form, `table[path]`, and the index is the dict's lookup — an optional `Response`, the value when the key is present, `null` when it is not — so `?? Response.notFound()` gives the fallback. The program prints `about` and `200` for the path the table holds, `404` for one it does not, then reads the table directly twice: `table["/"]?.body` is `home`, and `table["/nope"]` is absent, so the `?.` chain falls to `none`.

On every target the present key answers its value — never `undefined`, never an unsupported-index crash at boot, never a trap — and an absent key answers `null`, the same answer the lookup method gives.

Cells of this repository that prove it: none yet. rakun's own tables use `Dict.at` by name (`modules/rakun-app/src/ssr.bp`, `queryDict`); no cell of this repository indexes a `Dict` with `d["k"]`.

[draft/main.bp](draft/main.bp)
