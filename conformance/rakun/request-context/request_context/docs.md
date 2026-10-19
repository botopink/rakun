# request_context

{src/main.bp}

The reference text this cell shows (from [`../docs.md`](../docs.md), § The request context):

> `request_context.bp` is the server-side scope. Nothing else on the server can
> reach the in-flight request: a `Request` lives only inside the function the
> router dispatched to.
>
> `headersWire` is `name\tvalue` lines, `\n`-separated, names already lowercased
> by the dispatcher. `endRequest()` must run on the failure path too, or the next
> request on a keep-alive connection starts inside the previous one's frame.
>
> `RequestScope` implements `Renderable` (decision 354): a hook over the
> request is written `-> Component<T>`. The readers below are ordinary
> functions, not hooks.
>
> The scope is a FRAME with an EPOCH, not a process: a connection process serves
> many requests in sequence, so every handle minted from the frame carries the
> epoch it was minted with and raises if it is used after `endRequest` or from the
> next request. Reading outside a request is a hard failure — `requestPhase()`
> with no frame raises `request context is not established`, and there is no
> lenient mode, no `…Or(default)` and no predicate to branch around it. A library
> that has to work both inside and outside a request takes the values as
> parameters.
>
> The five phases are `Middleware`, `Render`, `Action`, `Handler` and `After`, and
> the phase is stored once: front 12's `rkCachePhase()` reads this slot rather
> than keeping a second one.
