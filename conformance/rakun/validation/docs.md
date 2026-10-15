# Validation

> Package: [`rakun`](../docs.md) · index: [`../../docs.md`](../../docs.md)

Validation is the library `validation` (`botopink/validation`, decision 116 rule
5), declared in `dependencies` like any library (decision 326). The server
and the browser run the same predicates from it. rakun hands it rakun's message
keys at boot (`Rakun.run` installs `config_check.installMessageSource()`), so
`rakun.validation.locale` and `rakun.validation.messages.<code>` work as before.

## The record, and the two functions it gets

{validated/src/main.bp}

`#[validated]` splices two functions into **this** module:

```text
pub fn validateCreateUserRequest(v: CreateUserRequest) -> ValidationReport
pub fn constraintsOfCreateUserRequest() -> string
```

The emission runs at the application site, so the application imports the names
the emitted bodies reference — the same rule `#[service]` lives by. `ValidationReport`
and `Violation` are imported **even where the application never spells them**: on the
erlang row a record method's owner module is resolved only when the type is
imported into the calling module, and without it `report.isValid()` lowers to an
unqualified call the BEAM compiler refuses.

Every constraint on a field runs; the first failure does not stop the second,
which is what makes a three-field form report three errors:

{validated/src/main.bp}

## The constraint set

| Marker | Applies to | Holds when |
|---|---|---|
| `#[notNull]` | a field whose type can be null | the value is not `null` |
| `#[notBlank]` | `string` | trimmed length > 0 |
| `#[notEmpty]` | `string`, `Array<T>` | length > 0 |
| `#[sizeBetween(min, max)]` | `string`, `Array<T>` | `min <= length <= max`, inclusive |
| `#[minValue(n)]` / `#[maxValue(n)]` | `i32`, `f64` | numeric bound, inclusive |
| `#[positive]` / `#[positiveOrZero]` | `i32`, `i64`, `f64` | sign |
| `#[email]` | `string` | the address grammar |
| `#[pattern(regex)]` | `string` | `std/regex` matches |
| `#[pastDate]` / `#[futureDate]` | `i64` epoch millis | strictly before / after the clock |
| `#[constraint(name)]` | `string` | the registered constraint answers `""` |

There is **no `#[future]`**: the name reads as the `future` effect annotation
that decision 118 removed. `#[sizeBetween]` names both bounds because a decorator argument's
declared default is not applied.

A marker on a field whose type it cannot check is a **located compile error**,
not a row that quietly always holds — `#[notBlank]` on an `i32` refuses, it does
not pass.

## Typed coercion of `Request`'s strings

`Request.param`/`query`/`header`/`body` all answer `string`, and `""` when
absent. The binders make the distinction and record a violation instead of
yielding a zero. Bind everything, then ask once:

{binders/src/main.bp}

`bindInt("age", "12x")` answers `0` **and** records a `typeMismatch` naming
`age`, so the zero can never be mistaken for a value the caller meant. The
accumulator is request-scoped: on the BEAM it is the serving process's
dictionary, so two concurrent requests cannot see each other's violations.

## An application constraint

{constraint/src/main.bp}

Reach it from a field with `#[constraint("cpf")]`. `check` answers `""` when the
value is acceptable and otherwise a message TEMPLATE — `{field}` and `{value}`
are substituted by the reporter. A name nothing is registered under is a
**violation** coded `unknownConstraint` naming what IS registered, at the first
validation call; it is never a pass.

Message templates resolve `rakun.validation.messages.<locale>.<code>` →
`rakun.validation.messages.<code>` → the built-in default, over front 05's
property table; the locale is `rakun.validation.locale`. A template naming a
placeholder the constraint does not have is left as written, because a visible
`{limit}` in an error message is a bug report and an empty string is not.

## Configuration that refuses to boot

{billing_config/src/main.bp}

`refuseInvalidConfig("BillingConfig", "app.billing", validateBillingConfig(cfg))`
halts with one line per violation, each naming its **property key**
(`app.billing.retryLimit: must be at most 10 (maxValue)`) rather than its field
name — the operator reads `application.yaml`, not the record. There is no flag
that turns the refusal into a warning.
