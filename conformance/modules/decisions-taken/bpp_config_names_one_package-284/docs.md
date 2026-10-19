# Decision 284 — Configuration in JSON, case by case.

The program is one page of a rakun-bpp application. Its manifest keeps one line of bpp configuration, `"bpp": "rakun-bpp"` — the one package that supplies the roles — and nothing else: which function is a page is not configured in JSON but found by the annotation that package declares, `#[page("")]` on `Home`. Rendered with a `PageContext` for `/`, the page prints `<div><p>home at /</p></div>`.

Any other configuration lives in `botopink.json` or in a JSON file of its own, decided feature by feature; the manifest is kept as small as it can be.

This draft builds against the workspace's dependencies; the manifest with its `"bpp"` line is the one `promote` writes beside it (front 166 s4).

Cells of this repository that prove it: none yet. No manifest of this repository carries a `"bpp"` field today; the roles' cells are `rakun-bpp/router` and `rakun-bpp/client-boundary/client_marker`, which find `#[page]` and `#[client]` by their annotations. The `"bpp"` field is fronts 116 and 124's and `07-onze/50`'s.

[draft/main.bp](draft/main.bp)
