# Rakun Modules

> Spring Boot 4-style framework for Botopink/Erlang — subdivided into focused modules.

This directory contains the Rakun framework modules, each covering a specific area of the Spring Boot 4 ecosystem. All modules are maintained in the same repository and share the same IoC container, decorator system, and Erlang runtime.

## Module Overview

| Module | Spring Boot Equivalent | Description |
|---|---|---|
| **rakun-core** (in `../src/`) | spring-boot-starter | IoC container, DI, config, profiles, lifecycle, events |
| [rakun-web](./rakun-web/) | spring-boot-starter-web | Middleware, CORS, error handling, WebSocket |
| [rakun-data](./rakun-data/) | spring-boot-starter-data-jpa / data-* | SQL (PostgreSQL, MySQL) + NoSQL (MongoDB, Redis, Elasticsearch) |
| [rakun-security](./rakun-security/) | spring-boot-starter-security | Authentication, authorization, JWT, Basic Auth |
| [rakun-actuator](./rakun-actuator/) | spring-boot-starter-actuator | Health, metrics, info, env, beans endpoints |
| [rakun-cache](./rakun-cache/) | spring-boot-starter-cache | @Cacheable, @CacheEvict, in-memory + Redis |
| [rakun-client](./rakun-client/) | spring-boot-starter-webflux (WebClient) | REST client (blocking + reactive) |
| [rakun-validation](./rakun-validation/) | spring-boot-starter-validation | Bean validation (@NotNull, @Size, @Email) |
| [rakun-messaging](./rakun-messaging/) | spring-boot-starter-amqp / kafka | AMQP/RabbitMQ + Kafka |
| [rakun-scheduling](./rakun-scheduling/) | @Scheduled | Task scheduling (cron, fixedRate, fixedDelay) |
| [rakun-logging](./rakun-logging/) | spring-boot-starter-logging | Structured logging (ECS, GELF, Logstash) |
| [rakun-session](./rakun-session/) | spring-boot-starter-session | Session management (in-memory + Redis) |
| [rakun-test](./rakun-test/) | spring-boot-starter-test | MockMvc, @MockBean, test utilities |
| [rakun-hateoas](./rakun-hateoas/) | spring-boot-starter-hateoas | Hypermedia (HAL links) |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Application Code                         │
│  #[service]  #[restController]  #[repository]  ...          │
├─────────────────────────────────────────────────────────────┤
│  rakun-web  │  rakun-security  │  rakun-actuator  │  ...   │
├─────────────────────────────────────────────────────────────┤
│  rakun-data  │  rakun-cache  │  rakun-messaging  │  ...    │
├─────────────────────────────────────────────────────────────┤
│                     rakun-core                                │
│  IoC Container · DI · Config · Profiles · Lifecycle · Events │
├─────────────────────────────────────────────────────────────┤
│              Runtime (Erlang / Node.js)                       │
│  runtime.erl (cowboy, ETS, poolboy)  │  runtime.mjs          │
└─────────────────────────────────────────────────────────────┘
```

## Usage

```bp
// In your application's botopink.json:
{
    "dependencies": {
        "rakun": { "git": "...", "branch": "feat" }
    }
}

// Import what you need:
import {service, restController, route, getMapping} from "rakun";
import {Rakun, App, Request, Response} from "rakun";

// Optional modules:
import {cacheable} from "rakun-cache";
import {secured} from "rakun-security";
import {RabbitTemplate, rabbitListener} from "rakun-messaging";
```

## Module Structure

Each module follows the same structure:

```
rakun-<name>/
├── botopink.json       # Package metadata
├── src/
│   ├── root.bp         # Module tree root
│   └── *.bp            # Implementation
└── test/
    └── *_test.bp       # Tests
```

## Development

### Adding a new module

1. Create `modules/rakun-<name>/` with `botopink.json`, `src/root.bp`, `test/`
2. Add `pub mod rakun_<name>;` to the workspace
3. Implement using `#[decorator]` pattern + `@emit` + runtime
4. Write tests for both commonJS and Erlang targets
5. Update this README

### Conventions

- **Decorator-based**: All annotations use `#[decorator]` syntax
- **IoC integration**: All components are managed by the rakun-core container
- **Dual-target**: Every module works on commonJS AND Erlang
- **Std lib reuse**: Use `std.*` modules (json, http, fs, env, crypto) when possible
- **No compiler changes**: The compiler core knows nothing about rakun modules

## Spring Boot 4 → Rakun Mapping

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
| `@RabbitListener` | `#[rabbitListener]` (rakun-messaging) |
| `@KafkaListener` | `#[kafkaListener]` (rakun-messaging) |
| `@PreAuthorize` | `#[preAuthorize]` (rakun-security) |
| `@CrossOrigin` | `#[crossOrigin]` (rakun-web) |
| `@Valid` | `#[valid]` (rakun-validation) |
| `application.yaml` | `application.yaml` (rakun-core config) |
| Profiles (`-Dspring.profiles.active`) | Profiles (`rakun.profiles.active`) |
| Actuator endpoints | `/actuator/*` (rakun-actuator) |
| `RestTemplate` / `RestClient` | `RestClient` (rakun-client) |
| `WebClient` | `WebClient` (rakun-client, reactive) |

## Version

Current: `0.0.1` (development)

Target: `1.0.6-beta` (see `specs/1.0.6-beta/`)
