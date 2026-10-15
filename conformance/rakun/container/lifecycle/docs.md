# lifecycle

{src/main.bp}

The reference text this cell shows (from [`../docs.md`](../docs.md), § Lifecycle hooks):

> A hook may use every injected dependency — it runs on the constructed instance.
> `#[postConstruct]` runs once per singleton however many sites resolve it, in
> registration order, and the pass is part of the eager initialization
> `context.bootSequence()` performs. `#[preDestroy]` runs on shutdown in REVERSE
> registration order, which is reverse dependency order.
>
> A `#[postConstruct]` that raises fails the boot, naming the component and the
> method — a half-built component is worse than a refused boot. A `#[preDestroy]`
> that raises is logged and the remaining hooks still run.
>
> The two markers are placement checks and emit nothing: a method-level `@Decl`
> carries no owner, so it cannot name the factory whose method it is. `#[managed]`
> sees both and emits the registration.
