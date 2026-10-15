# managed

{src/main.bp}

The reference text this cell shows (from [`../docs.md`](../docs.md), § `#[managed]` — registering a bean):

> `#[managed]` STACKS under a stereotype rather than replacing it — the way
> `#[route]` stacks under `#[restController]` — because the six stereotype
> decorators are frozen for this milestone. A type that carries a stereotype and no
> `#[managed]` is still scanned and still injectable as a field; it is simply not
> in the registry, so `ctx.resolve` will not find it.
>
> The module that declares a `#[managed]` type imports `rkRegisterBean` alongside
> the marker, the same way a `#[service]` module already imports `rkScan`,
> `rkSingleton`, `rkEnter` and `rkDone`: the wiring is `@emit`ted into the
> application's own module and calls those names there.
