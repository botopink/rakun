# provides

{src/main.bp}

The reference text this cell shows (from [`../docs.md`](../docs.md), § `#[provides]` — a factory function):

> `Clock` is now injectable by type — a `clock: Clock` field gets the `#[primary]`
> one — and `ctx.resolveNamed("Clock", "fixed")` reaches the other. It is not
> spelled `#[bean]` because `#[bean]` already exists and is frozen at a METHOD of a
> `#[configuration]`; `#[provides]` is the function form.
>
> Exactly one provider of a type may own the `__rkMake_<Type>()` name constructor
> injection reaches for: the unqualified one, or the `#[primary]` one. So:
>
> - **Two unqualified providers of one type** both register and the second raises
>   at module load, naming both functions.
> - **Two qualified providers with no `#[primary]`** own the name neither time, so
>   a FIELD of that type does not compile (`unbound variable '__rkMake_Dye'`) and
>   an unqualified `ctx.resolve` raises the ambiguity. `resolveNamed` still works —
>   which is the point of having qualified two beans in the first place.
>
> `#[provides]` on a function returning nothing is refused at comptime: a bean is
> what the function returns.

## Measured

The cell resolves through `Context` (`ctx.resolve`, `ctx.resolveNamed`) — the unqualified lookup answers the `#[primary]` provider.
