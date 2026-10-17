# managed

{src/main.bp}

The reference text this cell shows (from [`../docs.md`](../docs.md), § `#[managed]` — registering a bean):

> `#[managed]` STACKS under a stereotype rather than replacing it — the way
> `#[route]` stacks under `#[restController]` — because the six stereotype
> decorators are frozen for this milestone. A type that carries a stereotype and no
> `#[managed]` is still scanned and still injectable as a field; it is simply not
> in the registry, so `ctx.resolve` will not find it.
>
> A `#[service]` module imports `rkSingleton`, `rkEnter`, `rkDone` and `rkResolve`
> alongside the marker: the string members (`make()`, a `#[managed]` type's `new()`)
> run in the application's own module and call those names there. The registrations
> (`rkScan`, `rkRegisterBean`, `rkRequestScoped`) are executors (`compiler.compile`)
> whose names resolve in rakun, so the application imports none of them.
