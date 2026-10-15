# context

{src/main.bp}

The reference text this cell shows (from [`../docs.md`](../docs.md), § `Context`):

> `Context` is injectable BY TYPE: a field of it wires with no extra declaration,
> because rakun emits the `__rkMake_Context()` factory the component decorator
> already reaches for. The consumer's module names that factory in its `import`
> list, the same way it already names `rkScan` and `rkSingleton` — the emitted
> wiring calls those by name at the application site.
>
> `Context` is not a bean of its own registry: it does not appear in
> `ctx.beanNames()`, the eager pass does not construct it, and it is exempt from
> the cycle guard because it is constructed before the scan runs and depends on
> nothing.
>
> `ctx.child("request")` returns a context whose lookup starts in its own registry
> and delegates upward on a miss — Spring's parent/child contexts. A bean
> registered at the root is visible from every child; one registered into a child
> is not visible from the root. `ctx.path()` is the scope path and `""` is the
> root.
>
> **Bind the receiver to an ANNOTATED local.** `__rkMake_Context().resolve(…)` and
> `val ctx = __rkMake_Context();` both lose the optional's payload type — the
> optional a record method answers loses its type when the receiver is a call or an
> unannotated local. `val ctx: Context = __rkMake_Context();` is the spelling that
> keeps `?OrderCache` an `?OrderCache`.

## Measured

`Context` is reached by `rootContext()`; there is no `__rkMake_Context` to import.
