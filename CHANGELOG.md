# rakun · CHANGELOG

## Unreleased

- **The host runtime runs on the BEAM** (1.0.10-beta front 04, steps 1-4).
  `modules/rakun/src/sidecars/rakun_runtime.erl` is the erlang twin of
  `runtime.mjs`: an `application` whose `rakun_sup` supervises the
  `rakun_registry` `gen_server` that owns five `named_table, public,
  {read_concurrency, true}` ETS tables (scan list, singleton cache, build
  counts, property map, route table), with the dependency-cycle guard in the
  process dictionary. There is no `rakun.app` file — a sidecar is compiled at
  run time by `__bp_load_siblings/0` — so the spec is loaded from a term, which
  is what makes `application:start(rakun)` available in a plain
  `botopink test --target erlang` run. Fifteen of the sixteen cells in
  `src/runtime.bp` gained an `@External.Erlang("rakun_runtime", "<snake_case>")`
  form beside their node one (`rkServe` follows with the acceptor).
  The module atom is `rakun_runtime`, never `runtime`: `shipErlSidecars` skips
  an atom matching a module the build emitted, rakun emits `rakun/runtime`, and
  the skip is SILENT. Measured: `botopink test` 31/31 (was 17/17);
  `botopink test --target erlang` 21 passing (was 1) and
  `.botopinkbuild/test-out/rakun_runtime.erl` present. The six erlang reds that
  remain are two erlang-BACKEND gaps, recorded in `AGENTS.md` § Blocked;
  `botopink.json` keeps `targets: ["commonJS"]` until they close.

- **`test/erlang_runtime_test.bp`** names the host cells directly instead of
  reaching them through the decorators, so it covers what the older five cannot:
  declaration order in the scan registry, the `parseInt` rule behind
  `#[value("key")]` (`"12abc"` is `12` on BOTH rows), registration order between
  two matching routes, and the shape `Response` lowers to when it round-trips
  through a host call. Fourteen assertions, identical on commonJS and erlang.

- **The repository is a workspace** (`02-packaging` step 2; decisions 75 and 76 of
  1.0.10-beta). `botopink.json` at the root is `{ name, version, description, targets
  [commonJS, erlang], workspaces ["modules/*", "examples/*"] }` — no `src`, `files`, `target` or
  `dependencies`; `botopink build/test` there is the located refusal naming the members. The
  core moved with `git mv` to `modules/rakun/` (`src/**` incl. `runtime.mjs`, the five
  `test/*_test.bp`) and its manifest lists `files: [root, http, runtime, decorators, bootstrap,
  rakun.d]`, `targets: [commonJS]` (a restriction of the workspace's; front 04 adds erlang).
  The thirteen scaffolds gain `files: ["root.bp"]` (a library member without `files` is
  `✗ ships nothing`), `targets` per `03-rakun/modules.md` § Targets (erlang, except
  `rakun-validation` and `rakun-test`: both), and `{ "rakun": { "workspace": true } }` in place
  of the refused `{ "path": "../../" }`; none is renamed (every scaffold is a KEEP of the
  reconciliation table). `examples/rakun` is the member `rakun-example` (renamed from
  `rakun-app`, the name front 22's submodule takes — duplicate member names are refused),
  depending on `rakun` via `{ "workspace": true }` instead of the git form. The pre-commit
  runner is workspace-aware: `botopink test` in every `modules/*/` member, then the examples
  gate. Measured: core 17/17 commonJS at its new path; the example builds and answers the
  documented routes; `botopink-lib-test` prints 15 member rows and no umbrella row.

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
