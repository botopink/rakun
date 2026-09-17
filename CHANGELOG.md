# rakun · CHANGELOG

## Unreleased

- **The 1.0.3 surface** (botopink-lang front 12): records and the enum are `type`s, `Request`
  and `Context` are `behavior`s, and the sources are `botopink format`ted. The component
  markers check `decl.kind != DeclKind.Type` plus `decl.variants.length > 0` (an enum-shaped
  `type` is rejected: "#[service] must annotate a type with fields, not an enum"). commonJS
  17/17; the example server answers every baseline route identically.
- The examples gate no longer aborts silently on a `scripts/known-broken-examples.txt`
  holding only comments or blank lines: the runner reads the list with `awk`, whose
  "no entry" is not a failure under `set -euo pipefail`.

- **MIT license.** `LICENSE` (`Copyright (c) 2026 Eric Fillipe and botopink
  contributors`) backs the README's License section, which now points at it.

- The gate builds the examples: after `botopink test`, the pre-commit hook
  and CI run `botopink build` in every `examples/*/` with a `botopink.json`;
  `scripts/known-broken-examples.txt` lists the ones allowed to fail, and a
  listed example that builds fails the gate.
- The pre-commit hook is self-contained: the dead delegation to a meta
  workspace runner is gone, and `AGENTS.md` documents the install
  (`git config core.hooksPath scripts/git-hooks`) instead of a
  `scripts/install-hooks.sh` that exists in no repository.
- Promoted from workspace subdir to standalone repository under
  `botopink/rakun`. Tracked from `botopink/projects` as a git submodule on the
  `feat` branch.
- Dropped the `server` dependency, which named a library that exists in no
  repository (`botopink check` failed with `LibNotFound`). The node `http`
  transport `Rakun.run` starts is now rakun's own `serve` in `runtime.mjs`,
  bound as `rkServe` in `runtime.bp`. `botopink.json` gains `"target": "commonJS"`
  (the key the CLI reads) beside the lib-test `"targets"` whitelist.

## 0.0.1 — v0.beta.9

- **Scopes** (F2): `singleton` (default), `value` (config-bound), `bean` (factory).
- **Real HTTP server** (F5): `Rakun.run()` + node `http` module.
- Generic core: `commonJS` `require("../"×depth)` resolution + `libs.zig`
  sidecar shipping for `.mjs` files.
- Unit-test suite green + example serving over real HTTP.

## 0.0.0 — v0.beta.5

- Initial spec and framework scaffold; DI container core + `#[restController]`.
