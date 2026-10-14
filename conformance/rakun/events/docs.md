# events

The reference text this cell shows (from `conformance/docs.md`, § Application events):

> One `Event` record and a STRING name: Spring dispatches by the listener
> parameter's type, and a method-level `@Decl` carries no parameter list, so the
> event type cannot be read from the listener. Dispatch is synchronous and in
> registration order; a listener that raises is recorded and the others still run.
> An event nobody listens for delivers to zero listeners and is not an error.
>
> Build an event with `event(name, source, payload)`. `Event(name: …,
> timestampMillis: 0)` does not compile — an integer literal is `i32` and there is
> no widening to the `i64` field — and `event` stamps the clock itself.
>
> A module that imports `Context` must also import `Event`, because
> `Context.publish`'s parameter type has to resolve at the use site.

## Measured

The listener prints the event payload; the cell publishes through the router (`rkDispatch`), so the event carries the request path.
