# The container

> Package: [`rakun`](../docs.md) · index: [`../../docs.md`](../../docs.md)

Constructor injection resolves a field by type and needs no help. Everything
below is for the value that is *not* a field of something: resolving a bean
programmatically, running code at startup and shutdown, and publishing or
observing an application event.

## `#[managed]` — registering a bean

{managed/src/main.bp}

`#[managed]` STACKS under a stereotype rather than replacing it — the way
`#[route]` stacks under `#[restController]` — because the six stereotype
decorators are frozen for this milestone. A type that carries a stereotype and no
`#[managed]` is still scanned and still injectable as a field; it is simply not
in the registry, so `ctx.resolve` will not find it.

A `#[service]` module imports `rkSingleton`, `rkEnter`, `rkDone` and `rkResolve`
alongside the marker: the string members (`make()`, a `#[managed]` type's `new()`)
run in the application's own module and call those names there. The registrations
(`rkScan`, `rkRegisterBean`, `rkRequestScoped`) are executors (`compiler.compile`)
whose names resolve in rakun, so the application imports none of them.

## Resolving

{resolve/src/main.bp}

The registry key is a STRING and the type comes from the annotated binding.
`ctx.resolve<OrderCache>()` is not writable: explicit generic arguments do not
parse at a call site, and there is no `@typeName<T>()` to recover the name from
`T`. So `resolve<Foo>("Bar")` type-checks and answers `null` — the two halves are
not checked against each other, and both are recorded language gaps.

An unregistered type answers `null` and `rkHasBean` answers `false`; neither
raises. Two beans of one type raise only when an UNQUALIFIED `resolve` cannot
choose between them:

```text
rakun: two beans of type 'Clock' ('systemClock', 'fixedClock') and neither is
       #[primary]; resolve by qualifier, or mark one #[primary]
```

Mark one `#[primary]`, or reach for the one you meant with
`rkResolveNamed("Clock", "fixed")`.

## `Context`

{context/src/main.bp}

`Context` is injectable BY TYPE: a field of it wires with no extra declaration,
because rakun emits the `__rkMake_Context()` factory the component decorator
already reaches for. The consumer's module names that factory in its `import`
list, the same way it already names `rkScan` and `rkSingleton` — the emitted
wiring calls those by name at the application site.

`Context` is not a bean of its own registry: it does not appear in
`ctx.beanNames()`, the eager pass does not construct it, and it is exempt from
the cycle guard because it is constructed before the scan runs and depends on
nothing.

`ctx.child("request")` returns a context whose lookup starts in its own registry
and delegates upward on a miss — Spring's parent/child contexts. A bean
registered at the root is visible from every child; one registered into a child
is not visible from the root. `ctx.path()` is the scope path and `""` is the
root.

**Bind the receiver to an ANNOTATED local.** `__rkMake_Context().resolve(…)` and
`val ctx = __rkMake_Context();` both lose the optional's payload type — the
optional a record method answers loses its type when the receiver is a call or an
unannotated local. `val ctx: Context = __rkMake_Context();` is the spelling that
keeps `?OrderCache` an `?OrderCache`.

## `#[provides]` — a factory function

{provides/src/main.bp}

`Clock` is now injectable by type — a `clock: Clock` field gets the `#[primary]`
one — and `ctx.resolveNamed(Clock, "Clock", "fixed")` reaches the other. It is not
spelled `#[bean]` because `#[bean]` already exists and is frozen at a METHOD of a
`#[configuration]`; `#[provides]` is the function form.

Exactly one provider of a type may own the `__rkMake_<Type>()` name constructor
injection reaches for: the unqualified one, or the `#[primary]` one. So:

- **Two unqualified providers of one type** both register and the second raises
  at module load, naming both functions.
- **Two qualified providers with no `#[primary]`** own the name neither time, so
  a FIELD of that type does not compile (`unbound variable '__rkMake_Dye'`) and
  an unqualified `ctx.resolve` raises the ambiguity. `resolveNamed` still works —
  which is the point of having qualified two beans in the first place.

`#[provides]` on a function returning nothing is refused at comptime: a bean is
what the function returns.

## Lifecycle hooks

{lifecycle/src/main.bp}

A hook may use every injected dependency — it runs on the constructed instance.
`#[postConstruct]` runs once per singleton however many sites resolve it, in
registration order, and the pass is part of the eager initialization
`context.bootSequence()` performs. `#[preDestroy]` runs on shutdown in REVERSE
registration order, which is reverse dependency order.

A `#[postConstruct]` that raises fails the boot, naming the component and the
method — a half-built component is worse than a refused boot. A `#[preDestroy]`
that raises is logged and the remaining hooks still run.

The two markers are placement checks and emit nothing: a method-level `@Decl`
carries no owner, so it cannot name the factory whose method it is. `#[managed]`
sees both and emits the registration.

## Application events

{events/src/main.bp}

One `Event` record and a STRING name: Spring dispatches by the listener
parameter's type, and a method-level `@Decl` carries no parameter list, so the
event type cannot be read from the listener. Dispatch is synchronous and in
registration order; a listener that raises is recorded and the others still run.
An event nobody listens for delivers to zero listeners and is not an error.

Build an event with `event(name, source, payload)`. `Event(name: …,
timestampMillis: 0)` does not compile — an integer literal is `i32` and there is
no widening to the `i64` field — and `event` stamps the clock itself.

A module that imports `Context` must also import `Event`, because
`Context.publish`'s parameter type has to resolve at the use site.

## The boot sequence

{boot_sequence/src/main.bp}

`bootSequence()` publishes Spring's eight events, with the eager construction of
every registered bean and the `#[postConstruct]` pass between the fourth and the
fifth:

`ApplicationStarting` → `ApplicationEnvironmentPrepared` →
`ApplicationContextInitialized` → `ApplicationPrepared` → *[eager pass]* →
`ApplicationStarted` → `AvailabilityChanged(LivenessCorrect)` →
`ApplicationReady` → `AvailabilityChanged(ReadinessAcceptingTraffic)`

A missing property or a dependency cycle fails HERE, not on the first request
that touches it. When it does, `ApplicationFailed` is published in place of
everything after the point of failure and then the boot stops.

`main` calls it rather than `Rakun.run`, because `bootstrap.bp` is frozen.

## Scopes

{scopes/src/main.bp}

`singleton` (the default) is what constructor injection always gets.
`prototype` constructs on every `resolve`. `request` caches in the request
process's dictionary, so two resolves inside one request share an instance and
two requests do not — nearly free on the BEAM, where a request IS a process.

**A prototype or request bean carries no stereotype, and that is enforced.** The
stereotype is what emits the singleton `__rkMake_<Type>()` a FIELD is injected
through, so the pair would register a prototype and inject a singleton;
`#[managed]` refuses it at comptime. Without a stereotype there is no
`__rkMake_<Type>` at all, so a field of that type does not compile and the bean
is reached through `ctx.resolve`, which is the point. Such a type also may not
carry `#[postConstruct]` or `#[preDestroy]`: both passes run once, over an
instance nobody kept.

Front 62 owns the per-request accessors (`cookies()`, `headers()`, `after()`,
per-request memoization). Front 06 ships the scope kind and its storage and
defines no accessor.

## Eager initialization

With defaults, `context.bootSequence()` constructs every registered singleton
bean and runs every `#[postConstruct]` before it returns, so a dependency cycle
or a configuration reader that halts fails the BOOT rather than the first request
that happens to touch it.

```properties
rakun.main.lazy-initialization=true
```

turns it off — the `#[postConstruct]` pass with it, because a hook runs on an
instance. `#[lazy]` on one component excludes only that one. A `prototype` or
`request` bean is never eagerly built: it has no instance to warm.

A missing `#[value]` key is **not** a boot failure. `rkProp` answers `""` for an
absent key and `rkPropInt` answers `0`, by design and on both rows, so a missing
key is a default rather than an error — at boot or at any other time. Use front
05's typed configuration readers when a key is required.

## Shutdown and the exit code

{exit_code/src/main.bp}

`shutdown()` runs every `#[preDestroy]` in reverse registration order — reverse
dependency order, because a component is registered after the components it was
constructed from — and answers the process status: the highest value any
`#[exitCode]` function returns, or 0 with none registered. A hook that raises is
logged and the remaining ones still run.

Stopping accepting, flipping readiness false and draining the in-flight requests
are front 07's graceful shutdown, which calls `shutdown()` after the drain. A
failed boot never reaches it: the boot halts, and a halt is a non-zero process
status on both hosts.

## `#[imports]`

{imports/src/main.bp}

Spring's `@Import`: a bean is registered for each named type, so a configuration
record in a module the application does not otherwise reference is still wired.
Each named type must already have a factory — from a stereotype, a `#[bean]`
method or a `#[provides]` function — and a name with none does not compile,
naming both the type and the configuration that asked for it.

Spring's `@ComponentScan(basePackages=…)` has no analogue and needs none: an
additional scan root in botopink is a `pub mod` line.

## Qualifiers, primary and lazy

`#[qualifier("name")]` distinguishes two beans of one type, `#[primary]` marks
the default for the unqualified lookup, and `#[lazy]` keeps a bean out of the
eager pass. All three are read off the declaration by `#[managed]` and
`#[provides]`; on their own they are placement checks, the same split
`#[getMapping]` and `#[restController]` already use.
