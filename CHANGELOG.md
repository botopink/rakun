# rakun · CHANGELOG

## Unreleased

> **On the numbers below.** The shared compiler binary was rebuilt partway
> through front 05 and closed two erlang-backend gaps (module-level `val` side
> effects, `behavior` method dispatch). The counts in front 05's first two
> entries — 39/39 and 67/67 on commonJS, 29 and 57 passing on erlang — were
> taken with the PREVIOUS binary. Against the rebuilt one, with the whole front
> in the tree: `botopink test` 87/87 and `botopink test --target erlang` 85
> passing / 2 failing, the two reds being `{badkey,param}`/`{badkey,query}` in
> front 04's `server_test.bp`.

- **`#[configurationProperties]` binds a record, and every key it declares lands
  in a catalogue** (front 05, steps 7 and 9). The decorator emits
  `__rkBind_<Name>(prefix)`, the ordinary DI factory `__rkMake_<Name>()` and a
  module-load `val __rkCat_<Name> = rkRegisterConfigKeys(…)`. The prefix is a
  PARAMETER, which is what makes `#[nested]` compose without either decorator
  knowing the other — two levels are asserted — and the ordinary factory name is
  what makes a bound record injectable by type into a `#[service]` with no extra
  wiring, also asserted. `#[unit]`, `#[defaultValue]`, `#[validated]` and
  `#[enableConfigurationProperties]` come with it. `rkConfigLoad` registers
  rakun's own `rakun.main.*`, `rakun.server.*`, `rakun.config.*` and
  `rakun.profiles.*` keys beside the application's. Two departures from the
  spec, both recorded in `AGENTS.md`: relaxed binding is in the reader rather
  than the emitter (three spellings instead of one, and a decorator body cannot
  call a helper), and a list field is recognised by an EMPTY `@Decl` `typeName`,
  which is the only signal the reflection offers for a generic type.

- **Placeholders, random values and the typed readers** (front 05, steps 4 and
  8). `${key}` and `${key:default}` resolve at load time, recursively; an
  unresolvable reference with no default and a reference cycle each refuse the
  boot naming the keys. `${random.value|int|long|uuid|int(n)|int[lo,hi]}`
  resolves at REFERENCE time through `rkValue`, so two reads answer differently
  and nothing is cached — asserted with a thousand draws inside the range and a
  v4 UUID whose version and variant nibbles are checked. `Duration` and
  `DataSize` parse the Spring forms including ISO-8601, and an unparsable value
  halts naming the key, the value and the accepted forms. `rkPropBool`,
  `rkPropIntOr`, `rkPropFloat`, `rkPropList`, `rkPropDuration` and `rkPropSize`
  carry the declared default as their second argument (row 8) and do relaxed
  binding in the reader, so `remoteAddress` binds from `remote-address`,
  `remoteAddress` or `REMOTE_ADDRESS`.

- **Configuration resolves, in order, with profiles** (front 05, steps 2, 3, 5
  and 6). `rkConfigLoad()` merges the eight sources — command line,
  `RAKUN_APPLICATION_JSON`, `RAKUN_*` environment variables, profile documents,
  base documents, configuration trees, `rkSetProp`, declared defaults — each row
  with a test asserting it beats the row below, plus a full-stack test setting
  one key in six of them. `rakun.config.name`/`rakun.config.location` choose the
  documents, a location without `optional:` that does not exist refuses the boot
  naming the path, and `rakun.config.import` resolves after its importer with a
  cycle refused naming the chain. `src/profiles.bp` owns the profile set:
  `active`, `default`, `include[i]` and transitive `group.<name>[i]` (the group
  name activated beside its members, a self-reference refused), read back in
  activation order through `profiles.active()`. A document may carry
  `rakun.config.activate.on-profile` (names, `|`, `&`, `!`, parentheses) and
  `on-cloud-platform`, both of which must hold, and a document whose conditions
  do not hold contributes nothing. Measured: `botopink test` 67/67 (was 39/39);
  `botopink test --target erlang` 57 passing (was 29), the same six
  pre-existing reds.

- **Configuration documents load** (1.0.10-beta front 05, step 1).
  `modules/rakun/src/config.bp` reads `.properties` (comments, `\`
  continuations, `#---` document separators), `.json` (a flattening scanner that
  emits `server.port` and `a[0]` as it walks, written here because std's `json`
  answers a string with nothing to walk) and a documented YAML SUBSET (block
  mappings, block sequences, plain and quoted scalars, `#` comments, `---`
  separators) plus `configtree:` directories, and writes every entry through
  front 04's `rkSetProp` — two modules, one table. An anchor, an alias, flow
  style, a block scalar or a tag is a located refusal naming the file and the
  line. The readers are botopink rather than the spec's
  `sidecars/rakun_config.erl`: an erlang-only cell is a located node-row
  diagnostic at its call site, so it could not be asserted from `test/*.bp` at
  all (see `AGENTS.md` § Externalized configuration). Measured:
  `botopink test` 39/39 (was 31/31); `botopink test --target erlang` 29 passing
  (was 21), the same six pre-existing reds.

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
  form beside their node one; `rkServe` was paired with the acceptor, below.
  The module atom is `rakun_runtime`, never `runtime`: `shipErlSidecars` skips
  an atom matching a module the build emitted, rakun emits `rakun/runtime`, and
  the skip is SILENT. Measured: `botopink test` 31/31 (was 17/17);
  `botopink test --target erlang` 21 passing (was 1) and
  `.botopinkbuild/test-out/rakun_runtime.erl` present. The six erlang reds that
  remain are two erlang-BACKEND gaps, recorded in `AGENTS.md` § Blocked;
  `botopink.json` keeps `targets: ["commonJS"]` until they close.

- **The BEAM serves HTTP** (front 04, steps 5-9). `rakun_runtime` gained the
  `gen_tcp` acceptor (`{packet, http_bin}`, so OTP parses the request line and
  the headers and rakun writes no HTTP parser and depends on nothing outside
  `kernel`), one process per connection under `rakun_conn_sup`, per-request
  reply headers in the process dictionary, `boot/1` (banner, PID file, port
  file, headless, keep-alive), a startup-failure table consulted before the node
  halts, and the transport seam that delegates to `rakun_<name>:serve/2` — an
  unloadable named transport is a failure naming the module, never a silent fall
  back to the acceptor. `rkServe` is paired, so all sixteen cells now carry both
  forms. Cowboy is deliberately NOT a dependency: a sidecar is compiled by
  `compile:file/2` at run time with no rebar and no code path, so
  `cowboy:start_clear/3` would compile and then die with `undefined function`.
  `runtime.mjs` is frozen, so `set_reply_header/2`, `reply_headers_json/0`,
  `boot/1` and `add_failure/3` have no `rk*` cell — a cell with no node form
  reddens the commonJS row, which compiles every `test/*.bp` with no per-target
  gate. They are exercised from erlang instead; the key set is in `AGENTS.md`.

- **`targets` stays `["commonJS"]`** (front 04 step 10, a deliberate refusal).
  The erlang host module is complete and 21 of rakun's tests run on the BEAM,
  but `botopink test --target erlang` is not green: six registration assertions
  fail and `server_test.bp` does not compile, and every one of those reds is an
  erlang-BACKEND gap (`AGENTS.md` § Blocked), not rakun's. Widening `targets`
  now would move a known red into `botopink-lib-test` rather than fix anything;
  `erlang` joins in the change that closes the gaps. rakun has no line in
  `botopink-lang/scripts/known-red-libs.txt` — that file lives in the compiler
  repository and holds only its header — so nothing is deleted there either.
  The core manifest's description now names both host runtimes.

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
