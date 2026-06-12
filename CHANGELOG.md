# rakun · CHANGELOG

## Unreleased

- Promoted from workspace subdir to standalone repository under
  `botopink/rakun`. Tracked from `botopink/projects` as a git submodule on the
  `feat` branch.

## 0.0.1 — v0.beta.9

- **Scopes** (F2): `singleton` (default), `value` (config-bound), `bean` (factory).
- **Real HTTP server** (F5): `Rakun.run()` + node `http` module.
- Generic core: `commonJS` `require("../"×depth)` resolution + `libs.zig`
  sidecar shipping for `.mjs` files.
- 13 unit tests green + example serving over real HTTP.

## 0.0.0 — v0.beta.5

- Initial spec and framework scaffold; DI container core + `#[restController]`.
