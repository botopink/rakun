# boot_sequence

{src/main.bp}

The reference text this cell shows (from [`../docs.md`](../docs.md), § The boot sequence):

> `bootSequence()` publishes Spring's eight events, with the eager construction of
> every registered bean and the `#[postConstruct]` pass between the fourth and the
> fifth:
>
> `ApplicationStarting` → `ApplicationEnvironmentPrepared` →
> `ApplicationContextInitialized` → `ApplicationPrepared` → *[eager pass]* →
> `ApplicationStarted` → `AvailabilityChanged(LivenessCorrect)` →
> `ApplicationReady` → `AvailabilityChanged(ReadinessAcceptingTraffic)`
>
> A missing property or a dependency cycle fails HERE, not on the first request
> that touches it. When it does, `ApplicationFailed` is published in place of
> everything after the point of failure and then the boot stops.
>
> `main` calls it rather than `Rakun.run`, because `bootstrap.bp` is frozen.

## Measured

The cell stops at `bootSequence()`: the original continued with `Rakun.run`, which listens on a port. One listener per event makes the order visible; `AvailabilityChanged` fires twice.
