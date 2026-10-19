# Decision 676 — Every declared dependency's `"targets"` holds every target of the package that declares it, checked at the manifest; 660's order is depth-first by the manifests and by the deepest chain, as built.

The example is a package that builds for erlang alone, as the drafts' workspace does, and depends on
two packages of this repository: `rakun`, which declares `erlang`, and `rakun-style`, which declares
`erlang` and `commonJS`. Each dependency holds every target the package declares, so the manifest is
accepted and the program builds a two-layer rakun-style `Sheet` and answers it in a rakun `Response`:
`2`, then `200`. The check reaches through the graph: `rakun`'s own dependency `validation` is held
to `rakun`'s targets in turn.

The refused half is the manifest of a package that declares `commonJS` beside `erlang` and lists
`rakun` among its dependencies: it is refused at that dependency's line, `dependency-target-missing`,
`rakun declares no commonJS target`, whatever target the build is for — never compiled for a target
it does not declare, never skipped in silence. That is why `rakun-ssr`, which builds for commonJS,
leaves the rakun half of its boot to the erlang-only `onze-server`.

Proving cells: none in this repository; the check is the compiler's (660's step), proved by
botopink-lang's cells `dependency_target_missing` and `dependency_target_missing_transitive`.

[draft/main.bp](draft/main.bp)
