# Rakun modules

> Spring Boot 4-style framework for botopink — one workspace, one package per Spring starter.
> Decision document for the cut: `specs/1.0.10-beta/03-rakun/modules.md` · cross-cutting rules: `specs/1.0.10-beta/02-packaging/README.md` · decisions 75 and 76 in `specs/1.0.10-beta/decisions-taken.md`.

`repository/rakun/botopink.json` is a **workspace** (`"workspaces": ["modules/*", "examples/*"]`):
it compiles nothing, ships nothing, and `botopink build/test` there is a refusal that names the
members. Every directory here holding a `botopink.json` is a **member**; its manifest `name` is its
import name (`from "rakun-service"`). The core is the member `modules/rakun/` — `from "rakun"` resolves to
it, never to the umbrella. A member depends on a sibling with `{ "workspace": true }` only; a `path`
to a sibling or to the umbrella is a located error.

## Members today

Twenty members (front 165 s2): the 17 packages of the table in
[`../AGENTS.md`](../AGENTS.md) § The workspace and its layers, `rakun-cli` (the `rakun` command line), and the two
that wait on a later step or a question — `jhonstart-dom-test` (the
commonJS-only half of the bpp render tests, which cannot join a package that builds for erlang) and `onze-server` (the
erlang-only half of `rakun-ssr`'s boot, which cannot join a package that builds for commonJS). Front 128 merged
nine members into the member that needs them and front 165 folded the rest the same way: a folded package's files sit
in a same-named sub-directory of the absorber's `src/` and `test/`, its sidecars and `.mjs` runtimes beside the
absorber's in `src/sidecars/`, its names are imported by their path from the package root or by `from "<package>"`.

| Package | Absorbs (sub-folder of `src/` and `test/`) | `targets` | State |
|---|---|---|---|
| [rakun](./rakun/) (core) | `rakun` · `testing/` (was `rakun-test`: FakeRequest, assertions, MockMvc, context control) · `actuator_api/` · `logging/` | erlang | real code |
| [rakun-data](./rakun-data/) | `rakun-data` · `sql/` · `orm/` · `migration/` · `tx/` · `devtools/` (dbcontext folded in, s3) | erlang | real code |
| [rakun-restclient](./rakun-restclient/) | was `rakun-client` · `ws/` (SOAP) | erlang | real code |
| [rakun-style](./rakun-style/) | was `styled` | erlang, commonJS | real code |
| [rakun-bpp](./rakun-bpp/) | was `jhonstart` · `html/` · `link/` · `forms/` · `testing/` | commonJS, erlang | real code |
| [rakun-stylesheet](./rakun-stylesheet/) | was `emilia` · `testing/` · `bridge/` (was `jhonstart-emilia`) | commonJS, erlang | real code |
| [rakun-service](./rakun-service/) | was `rakun-web` (filter chain, CORS, problem details, TLS seam, `hateoas/`) · `actuator/` (was `rakun-actuator`) | erlang | real code |
| [rakun-scheduling](./rakun-scheduling/) | `rakun-scheduling` · `jobstore/` | erlang | real code |
| [rakun-session](./rakun-session/) | `rakun-session` | erlang | real code |
| [rakun-cache](./rakun-cache/) | `rakun-cache` | erlang | real code |
| [rakun-security](./rakun-security/) | `rakun-security` · `oauth2/` · `saml2/` · `ldap/` | erlang | real code |
| [rakun-websocket](./rakun-websocket/) | `rakun-websocket` | erlang | real code |
| [rakun-metrics](./rakun-metrics/) | `rakun-metrics` | erlang | real code |
| [rakun-messaging](./rakun-messaging/) | `rakun-messaging` · `reliability/` · `jms/` · `pulsar/` · `rsocket/` · `stream/` | erlang | real code |
| [rakun-mail](./rakun-mail/) | `rakun-mail` | erlang | real code |
| [rakun-app](./rakun-app/) | `rakun-app` (the `app/` router, SSR, actions) | erlang | real code |
| [rakun-ssr](./rakun-ssr/) | was `onze` · `cli/` · `server/` · `bundler/` · `assets/` · `content/` · `og/` · `release/` · `testing/` | commonJS, erlang | real code |
| [rakun-cli](./rakun-cli/) | `rakun-cli` · `release/` | erlang | real code |
| [jhonstart-dom-test](./jhonstart-dom-test/) | the bpp render's browser half, run on node | commonJS | real code |
| [onze-server](./onze-server/) | the rakun half of `rakun-ssr`'s boot (`Onze.run`) — erlang-only, so it cannot join the commonJS-built `rakun-ssr` | erlang | real code |

`modules/rakun-service/` stopped being a scaffold with front 07: it carries the filter chain, CORS and
RFC 9457 problem details, its host file (`src/sidecars/rakun_chain.erl`) and its test files — see `repository/rakun/AGENTS.md` § The filter chain. Front 14's `modules/rakun-validation/` is now the `validation` library — see
`repository/rakun/AGENTS.md` § Validation, and the section below.

### `validation` — front 14's member, now a library of its own (decisions 116 rule 5, 326)

Every other server module is erlang. This one is both, and the reason is the
mechanism rather than the packaging: `#[validated]` emits a plain botopink
function whose body is string comparisons, length checks and regex matches — no
host cell in the predicate path — so ONE source compiles for erlang and for
commonJS and the server and the client run the same predicate instead of two
predicates that are supposed to agree. What is serialized is only the constraint
table, and only for a consumer that is not botopink.

Surface, reached with `import {…} from "validation"`:

| What | Names |
|---|---|
| the report | `Violation`, `ValidationReport` (`isValid` · `merge` · `toJson` · `toProblemDetail` · `empty` · `of`), `jsonEscape` |
| the decorators | `#[validated]`; `#[notNull]` `#[notBlank]` `#[notEmpty]` `#[sizeBetween(min, max)]` `#[minValue(n)]` `#[maxValue(n)]` `#[positive]` `#[positiveOrZero]` `#[email]` `#[pattern(regex)]` `#[pastDate]` `#[futureDate]` `#[constraint(name)]` |
| what `#[validated]` emits | `validate<TypeName>(v) -> ValidationReport` and `constraintsOf<TypeName>() -> string` — **a contract front 05 calls by name**, not a convention |
| the predicates the emission calls | `vNotNull` `vNotBlank` `vNotEmpty` `vNotEmptyList` `vSizeBetween` `vSizeBetweenList` `vMinValueI32` `vMaxValueI32` `vMinValueF64` `vMaxValueF64` `vPositiveI32` `vPositiveOrZeroI32` `vPositiveI64` `vPositiveOrZeroI64` `vPositiveF64` `vPositiveOrZeroF64` `vEmail` `vPattern` `vPastDate` `vFutureDate` `vConstraint` |
| the table | `constraintTableJson`, `splitBlob`, `paramNames`, `renderParam` |
| the SPI | `behavior Constraint`, `registerConstraint(name, code, check)`, `constraintRegistered`, `registeredConstraints`, `clearConstraints` |
| messages | `templateFor`, `interpolate`, `message`, `arg`, `builtInTemplate`, `messagePrefix`, `localeKey` |
| binding | `bindInt` `bindBool` `bindRequired` `bindEpochMillis` `bindingReport` `bindingCount` `bindingReset` `bindingIsolated` `isIntegerText` `parseI32` `parseI64` |
| boot refusal | `propertyKey`, `violationLine`, `configProblem`, `refuseInvalidConfig` |

An application also imports `ValidationReport` and `Violation` even where it
never spells them: the erlang backend resolves a record method's owner module
only when the type is imported into the calling module. `repository/rakun/AGENTS.md`
§ Validation carries the measurement and the rest of the contract.

Every scaffold's `dependencies` is `{ "rakun": { "workspace": true } }` only. The sibling edges of
`03-rakun/modules.md` § The cut (`rakun-session → rakun-service, rakun-data`, `rakun-security → rakun-service,
rakun-data, rakun-restclient, rakun-session`, …) are added by the lowest-numbered front of each module,
which owns its `botopink.json` — several of them name members that do not exist yet.

## How the members came to be (the 1.0.10 cut, then decision 187)

| Member | Front | Origin in the cut |
|---|---|---|
| `rakun-actuator-api` | 11 (Step 0) | created, then merged into the core by front 128 (`modules/rakun/src/actuator_api/`, decision 187) |
| `rakun-app` | 22 (+ 23 · 24 · 25 · 60 · 61 · 63 · 64 · 66) | split from core — the `app/` router, SSR, actions; depends on `rakun-service`, `rakun-cache` |
| `rakun-websocket` | 20 | split from `rakun-service` |
| `rakun-tx` | 83 | created, then merged into `rakun-data` by front 128 (`modules/rakun-data/src/tx/`, decision 187) |
| `rakun-cli` | 88 | keep, separate |
| `rakun-stream` | 89 | created, then merged into `rakun-messaging` by front 128 (`modules/rakun-messaging/src/stream/`, decision 187) |
| `rakun-pulsar` | 91 | never split: Pulsar stays in `rakun-messaging/src/pulsar/` (decision 274) |
| `rakun-rsocket` | 92 | created, then merged into `rakun-messaging` by front 128 (`modules/rakun-messaging/src/rsocket/`, decision 187) |
| `rakun-mail` | 85 | keep, separate |
| `rakun-ws` (SOAP) | 93 | created as `rakun-ws`, then merged into `rakun-restclient` by front 128 (`modules/rakun-restclient/src/ws/`; merged, not renamed — decision 187) |

The `rakun-starter-*` packages (front 73) went with front 165 s2: a starter was a combination of thin packages and
`examples/` shows the combinations. `rakun-core` and
`rakun-observability` are aliases the cut drops.

## Consuming a member

```json
// inside this workspace (a member or an example):
"dependencies": { "rakun": { "workspace": true }, "rakun-service": { "workspace": true } }

// outside the ecosystem, after a release:
"dependencies": { "rakun": { "git": "https://github.com/botopink/rakun.git", "branch": "feat" } }
```

```bp
import {service, restController, route, getMapping} from "rakun";
import {Rakun, App, Request, Response} from "rakun";
import {filter, order, Chain, WebRequest} from "rakun-service";
import {validated, notBlank, email} from "validation";
// later, per front:
import {cacheable} from "rakun-cache";
import {secured} from "rakun-security";
```

> **`validated` comes from `validation`, never from `rakun`, and never
> both.** The core carries a *placement-only* `#[validated]` of its own
> (`modules/rakun/src/config.bp`, front 05): it checks placement and **emits
> nothing**, so importing that one leaves `validate<TypeName>` undefined and the
> failure lands at the call site as an unbound variable rather than at the
> annotation. Importing both names into one module is a duplicate binding.

## Member structure

```
rakun-<name>/
├── botopink.json       name (= import name) · src · entry root.bp · target · targets ⊆ the
│                       workspace's · files (every module a consumer may import, root.bp first) ·
│                       dependencies { "<sibling>": { "workspace": true } }
├── src/
│   ├── root.bp         module-tree root (`pub mod …`)
│   ├── *.bp            implementation
│   └── sidecars/       rakun_<name>.erl / *.mjs host modules the CLI ships beside the output
└── test/
    ├── *_test.bp       flat suite; may import the package
    └── __snapshots__/  beside the tests that write them
```

`botopink test` inside a member runs its own `src/` + `test/`; a library member without `files` is
`✗ ships nothing`. The pre-commit gate (`scripts/git-hooks/lib/runner-standalone.sh`) runs
`botopink test` in every `modules/*/` and `botopink build` in every `examples/*/`; the compiler's
`zig build test-libs` discovers the same members and prints one row per member, none for the umbrella.

## Adding a member

1. Create `modules/rakun-<name>/` with `botopink.json` (`name`, `files`, `targets`, `dependencies`
   in the workspace form), `src/root.bp`, `test/`. The glob `modules/*` picks it up; nothing else to register.
2. Depend on siblings with `{ "workspace": true }`; never `path`, never the umbrella.
3. Implement with the `#[decorator]` pattern + `compiler.compile` + a host sidecar under `src/sidecars/`.
4. Update this README and the member row above in the same commit.

## Conventions

- **Decorator-based**: all annotations use `#[decorator]` syntax.
- **IoC integration**: every component is managed by the core container (`rakun`).
- **Target per member**: erlang, every member and the workspace root (decision 117 rule 9);
  what the browser runs too is a shared library (`routing`, `actions`, `validation` — repositories of their own, decision 326), declared in `dependencies`, not a member.
- **Std lib reuse**: use `std.*` modules when possible; `std` is never listed as a dependency.
- **No compiler changes**: the compiler core knows nothing about rakun modules.

## Spring Boot 4 → Rakun mapping

| Spring Boot 4 | Rakun |
|---|---|
| `@SpringBootApplication` | `Rakun.run(App(...))` |
| `Component` / `@Service` / `@Repository` | `#[component]` / `#[service]` / `#[repository]` |
| `@RestController` + `@RequestMapping` | `#[restController]` + `#[route("/path")]` |
| `@GetMapping` / `@PostMapping` | `#[getMapping]` / `#[postMapping]` |
| `@Autowired` (constructor) | Field of the type (injected by type) |
| `@Configuration` + `@Bean` | `#[configuration]` + `#[bean]` |
| `@Value("key")` | `#[value("key")]` |
| `@Cacheable` | `#[cacheable]` (rakun-cache) |
| `@Scheduled` | `#[scheduled]` (rakun-scheduling) |
| `@RabbitListener` / `@KafkaListener` | `#[rabbitListener]` / `#[kafkaListener]` (rakun-messaging) |
| `@PreAuthorize` | `#[preAuthorize]` (rakun-security) |
| `@CrossOrigin` | `#[crossOrigin]` (rakun-service) |
| `@Valid` / `@NotBlank` / `@Size` / `@Email` … | `#[validated]` + the constraint markers (the library `validation`) — an explicit `validate<TypeName>(v)` call, not a parameter hook |
| Actuator endpoints | `/actuator/*` (rakun-service) |
| `RestClient` / `WebClient` | `RestClient` / `WebClient` (rakun-restclient) |

## Version

Current: `0.0.1` (development). Target: `1.0.10-beta` (`specs/1.0.10-beta/03-rakun/`).
