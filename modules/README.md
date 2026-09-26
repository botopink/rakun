# Rakun modules

> Spring Boot 4-style framework for botopink — one workspace, one package per Spring starter.
> Decision document for the cut: `specs/1.0.10-beta/03-rakun/modules.md` · cross-cutting rules: `specs/1.0.10-beta/02-packaging/README.md` · decisions 75 and 76 in `specs/1.0.10-beta/decisions-taken.md`.

`repository/rakun/botopink.json` is a **workspace** (`"workspaces": ["modules/*", "examples/*"]`):
it compiles nothing, ships nothing, and `botopink build/test` there is a refusal that names the
members. Every directory here holding a `botopink.json` is a **member**; its manifest `name` is its
import name (`from "rakun-web"`). The core is the member `modules/rakun/` — `from "rakun"` resolves to
it, never to the umbrella. A member depends on a sibling with `{ "workspace": true }` only; a `path`
to a sibling or to the umbrella is a located error.

## Members today

Fourteen members exist. The ten remaining scaffolds are **kept under their names** by the reconciliation
table of `03-rakun/modules.md` § Verdicts (no rename applied to a scaffold); each is a two-comment
`src/root.bp` until its front lands, and its manifest lists `files: ["root.bp"]` so it ships one module
rather than nothing. `targets` follows `03-rakun/modules.md` § Targets. Three members hold real code
today: the core (`rakun`, fronts 04 · 05 · 06 · 62 · 72 · 74), `rakun-app` (fronts 22 · 23, relocated
out of the core by front 95) and `rakun-web` (front 07). `rakun-test` holds front 19's request double,
assertions, MockMvc and context control. Front 14's
`rakun-validation` moved to the compiler-bundled library `validation` (decision 116 rule 5); its boot
refusal is the core's `config_check.bp`.

| Member | `files` | `targets` | Spring Boot 4 | Front(s) | State |
|---|---|---|---|---|---|
| [rakun](./rakun/) (core) | root · http · runtime · decorators · bootstrap · rakun.d · … | erlang | `spring-boot-starter` | 04 · 05 · 06 · 62 · 72 · 74 | real code, 347 tests |
| [rakun-app](./rakun-app/) | root · file_router · ssr · route_handler | erlang | (Next.js `app/` router, server half) | 22 · 23 · 24 · 25 · 60 · 61 · 63 · 64 · 66 | real code, 53 tests |
| [rakun-actuator-api](./rakun-actuator-api/) | root · contract · registration · span | erlang | `spring-boot-actuator` (the API half) | 11 (Step 0) | real code, 10 tests |
| [rakun-actuator](./rakun-actuator/) | root · endpoint_host · health · info · registry_endpoints · instrumentation · actuator | erlang | `-actuator` (host) | 11 · 76 · 87 | real code, 38 tests |
| [rakun-cache](./rakun-cache/) | root | erlang | `-cache` | 12 | scaffold |
| [rakun-client](./rakun-client/) | root · address · settings · response · cache · transport · health · client · request · exchange | erlang | `RestClient` / `WebClient` | 13 | real code, 70 tests |
| [rakun-data](./rakun-data/) | root · datasource · sql | erlang | `-data-jpa` / `-data-jdbc` / `-data-mongodb` / `-data-redis` | 08 · 09 · 77 · 78 | real code, 77 tests |
| [rakun-hateoas](./rakun-hateoas/) | root · hal | erlang | `-hateoas` | 21 | real code, 14 tests |
| [rakun-logging](./rakun-logging/) | root · cells · levels · formats · correlation · logging · digest · setup · endpoints | erlang | `-logging` | 17 | real code, 54 tests |
| [rakun-messaging](./rakun-messaging/) | root | erlang | `-amqp` / `-kafka` / `-activemq` / `-artemis` | 15 · 86 · 90 | scaffold |
| [rakun-scheduling](./rakun-scheduling/) | root · cron · registry · markers · executor · endpoint | erlang | `@Scheduled` / `-quartz` | 16 · 84 | real code, 67 tests |
| [rakun-security](./rakun-security/) | root · principal · policy · jwt · password · users · users_sql · basic · csrf · method_security · security_filter · security | erlang | `-security`, `-oauth2-client`, `-saml2` | 10 · 79 | real code, 73 tests |
| [rakun-session](./rakun-session/) | root · host · session · signing · session_config · session_cookie · store_ets · store_sql · store_redis · session_filter · session_endpoint | erlang | `spring-session-jdbc` / `-data-redis` | 18 | real code, 36 tests |
| [rakun-test](./rakun-test/) | root | erlang | `-test` | 19 | FakeRequest + toRequest, expect* assertions, MockMvc, resetSingletons/resetContext/contextSnapshot; 26 tests |
| [rakun-web](./rakun-web/) | root · filter · negotiation · error · middleware · cors · compression · customizer · apiversion · shutdown · convention · tls | erlang | `-webmvc` (websocket is `rakun-websocket`) | 07 · 65 · 82 | real code, 154 tests |

`modules/rakun-web/` stopped being a scaffold with front 07: it carries the filter chain, CORS and
RFC 9457 problem details, its host file (`src/sidecars/rakun_chain.erl`) and its test files — see `repository/rakun/AGENTS.md` § The filter chain. Front 14's `modules/rakun-validation/` is now the bundled `validation` library — see
`repository/rakun/AGENTS.md` § Validation, and the section below.

### `validation` — front 14's member, now a bundled library (decision 116 rule 5)

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
`03-rakun/modules.md` § The cut (`rakun-session → rakun-web, rakun-data`, `rakun-security → rakun-web,
rakun-data, rakun-client, rakun-session`, …) are added by the lowest-numbered front of each module,
which owns its `botopink.json` — several of them name members that do not exist yet.

## Planned members (not created here — each is its front's job)

| Member | Front | Origin in the cut |
|---|---|---|
| `rakun-actuator-api` | 11 (Step 0) | keep (create) — the API half every indicator registers into |
| `rakun-app` | 22 (+ 23 · 24 · 25 · 60 · 61 · 63 · 64 · 66) | split from core — the `app/` router, SSR, actions; depends on `jhonstart`, `emilia` |
| `rakun-websocket` | 20 | split from `rakun-web` |
| `rakun-tx` | 83 | keep, separate |
| `rakun-metrics` | 75 | keep, one name (`rakun-observability` dropped as alias) |
| `rakun-devtools` | 80 | keep, separate |
| `rakun-release` | 81 | keep, separate |
| `rakun-cli` | 88 | keep, separate |
| `rakun-stream` | 89 | keep, separate |
| `rakun-pulsar` | 91 | split from `rakun-messaging` |
| `rakun-rsocket` | 92 | keep, separate |
| `rakun-mail` | 85 | keep, separate |
| `rakun-soap` | 93 | rename of the 1.0.9 `rakun-ws` (never scaffolded — nothing to move) |
| `../starters/rakun-starter-*` | 73 | manifests beside `modules/`, not a module (`rakun-starters` dropped) |

Twenty-seven members in all when every front has landed, plus `starters/`. `rakun-core` and
`rakun-observability` are aliases the cut drops.

## Consuming a member

```json
// inside this workspace (a member or an example):
"dependencies": { "rakun": { "workspace": true }, "rakun-web": { "workspace": true } }

// outside the ecosystem, after a release:
"dependencies": { "rakun": { "git": "https://github.com/botopink/rakun.git", "branch": "feat" } }
```

```bp
import {service, restController, route, getMapping} from "rakun";
import {Rakun, App, Request, Response} from "rakun";
import {filter, order, Chain, WebRequest} from "rakun-web";
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
3. Implement with the `#[decorator]` pattern + `@emit` + a host sidecar under `src/sidecars/`.
4. Update this README and the member row above in the same commit.

## Conventions

- **Decorator-based**: all annotations use `#[decorator]` syntax.
- **IoC integration**: every component is managed by the core container (`rakun`).
- **Target per member**: erlang, every member and the workspace root (decision 117 rule 9);
  what the browser runs too is a bundled library (`routing`, `actions`, `validation`), not a member.
- **Std lib reuse**: use `std.*` modules when possible; `std` is never listed as a dependency.
- **No compiler changes**: the compiler core knows nothing about rakun modules.

## Spring Boot 4 → Rakun mapping

| Spring Boot 4 | Rakun |
|---|---|
| `@SpringBootApplication` | `Rakun.run(App(...))` |
| `@Component` / `@Service` / `@Repository` | `#[component]` / `#[service]` / `#[repository]` |
| `@RestController` + `@RequestMapping` | `#[restController]` + `#[route("/path")]` |
| `@GetMapping` / `@PostMapping` | `#[getMapping]` / `#[postMapping]` |
| `@Autowired` (constructor) | Field of the type (injected by type) |
| `@Configuration` + `@Bean` | `#[configuration]` + `#[bean]` |
| `@Value("key")` | `#[value("key")]` |
| `@Cacheable` | `#[cacheable]` (rakun-cache) |
| `@Scheduled` | `#[scheduled]` (rakun-scheduling) |
| `@RabbitListener` / `@KafkaListener` | `#[rabbitListener]` / `#[kafkaListener]` (rakun-messaging) |
| `@PreAuthorize` | `#[preAuthorize]` (rakun-security) |
| `@CrossOrigin` | `#[crossOrigin]` (rakun-web) |
| `@Valid` / `@NotBlank` / `@Size` / `@Email` … | `#[validated]` + the constraint markers (the bundled `validation`) — an explicit `validate<TypeName>(v)` call, not a parameter hook |
| Actuator endpoints | `/actuator/*` (rakun-actuator) |
| `RestClient` / `WebClient` | `RestClient` / `WebClient` (rakun-client) |

## Version

Current: `0.0.1` (development). Target: `1.0.10-beta` (`specs/1.0.10-beta/03-rakun/`).
