# scopes

{src/main.bp}

The reference text this cell shows (from [`../docs.md`](../docs.md), § Scopes):

> `singleton` (the default) is what constructor injection always gets.
> `prototype` constructs on every `resolve`. `request` caches in the request
> process's dictionary, so two resolves inside one request share an instance and
> two requests do not — nearly free on the BEAM, where a request IS a process.
>
> **A prototype or request bean carries no stereotype, and that is enforced.** The
> stereotype is what emits the singleton `__rkMake_<Type>()` a FIELD is injected
> through, so the pair would register a prototype and inject a singleton;
> `#[managed]` refuses it at comptime. Without a stereotype there is no
> `__rkMake_<Type>` at all, so a field of that type does not compile and the bean
> is reached through `ctx.resolve`, which is the point. Such a type also may not
> carry `#[postConstruct]` or `#[preDestroy]`: both passes run once, over an
> instance nobody kept.
>
> Front 62 owns the per-request accessors (`cookies()`, `headers()`, `after()`,
> per-request memoization). Front 06 ships the scope kind and its storage and
> defines no accessor.

## Measured

The cell shows a prototype bean built on every resolve and the request-scope cache by key (`rkRequestScoped` / `rkRequestScopeEnd`).
