# resolve

{src/main.bp}

The reference text this cell shows (from [`../docs.md`](../docs.md), § Resolving):

> The registry key is a STRING and the type comes from the annotated binding.
> `ctx.resolve<OrderCache>()` is not writable: explicit generic arguments do not
> parse at a call site, and there is no `@typeName<T>()` to recover the name from
> `T`. So `resolve<Foo>("Bar")` type-checks and answers `null` — the two halves are
> not checked against each other, and both are recorded language gaps.
>
> An unregistered type answers `null` and `rkHasBean` answers `false`; neither
> raises. Two beans of one type raise only when an UNQUALIFIED `resolve` cannot
> choose between them:

## Measured

`rkResolve` answers the value itself (it is the factory the emitted wiring calls) — the optional lookups are `rkFind` and `rkFindNamed`, and the cell uses those. The sentence about `resolve<Foo>("Bar")` answering `null` was not borne out while writing the cell: `rkFind("OrderCache")` bound to a `?Clock` answered a value, not `null`. The cell does not pin it.
