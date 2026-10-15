# exit_code

{src/main.bp}

The reference text this cell shows (from [`../docs.md`](../docs.md), § Shutdown and the exit code):

> `shutdown()` runs every `#[preDestroy]` in reverse registration order — reverse
> dependency order, because a component is registered after the components it was
> constructed from — and answers the process status: the highest value any
> `#[exitCode]` function returns, or 0 with none registered. A hook that raises is
> logged and the remaining ones still run.
>
> Stopping accepting, flipping readiness false and draining the in-flight requests
> are front 07's graceful shutdown, which calls `shutdown()` after the drain. A
> failed boot never reaches it: the boot halts, and a halt is a non-zero process
> status on both hosts.
