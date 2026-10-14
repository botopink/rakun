# usage

The reference text this cell shows (from `conformance/docs.md`, § Usage):

> `Request.param`/`query`/`header` return a plain `string` (`""` when absent) — a
> matched route's path params are always present, and `""` is the natural default
> for a missing query/header (Spring's `@RequestParam(defaultValue = "")`).
>
> The emitted DI/router wiring calls the host runtime by name, so a module
> declaring components imports those fns too (`rkScan`/`rkSingleton`/`rkEnter`/
> `rkDone`/`rkRegisterRoute`; add `rkProp`/`rkPropInt` when it has a `#[value]`
> field). See the runnable end-to-end app under
> [`./examples/rakun/`](examples/rakun/).

## Measured

The cell drives the router with `rkDispatch` instead of `Rakun.run`, which would listen on a port and never return. Measured against the example as printed here: `type GreetingService { … }` without parentheses is a namespace type and the beam backend refuses its `self`, so the cell writes `GreetingService()`; the emitted wiring also calls `rkResolve`, which the original import list did not name.
