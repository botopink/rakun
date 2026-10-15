# Web layer

> Package: [`rakun`](../docs.md) · index: [`../../docs.md`](../../docs.md)

A `#[restController]` with route decorators, the `Request` behavior and the
`Response` builders, wired by the component scan.

{usage/src/main.bp}

`Request.param`/`query`/`header` return a plain `string` (`""` when absent) — a
matched route's path params are always present, and `""` is the natural default
for a missing query/header (Spring's `@RequestParam(defaultValue = "")`).

The emitted DI/router wiring calls the host runtime by name, so a module
declaring components imports those fns too (`rkScan`/`rkSingleton`/`rkEnter`/
`rkDone`/`rkRegisterRoute`; add `rkProp`/`rkPropInt` when it has a `#[value]`
field). See the runnable end-to-end app under
[`examples/rakun/`](../../../examples/rakun/).
