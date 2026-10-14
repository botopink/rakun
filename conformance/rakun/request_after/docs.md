# request_after

The reference text this cell shows (from `conformance/docs.md`, § `after()`):

> The work runs once the response is sent, against a FROZEN copy of the frame
> under phase `After`: it can read the request's headers and cookies and can write
> nothing — a cookie write and a second `after()` both raise there. The dispatcher
> calls `endRequest()`, writes the response, then `drainAfter(budget)`;
> `rakun.request.after.timeout` (default 30 000 ms) bounds each thunk, and
> `afterLog()` carries one line per failure or kill, each with the request id.
>
> On the BEAM a thunk is a `spawn_monitor` child and an overrunning one is killed.
> Node cannot interrupt a synchronous function, so it counts a thunk that overran
> in the same slot — same counters, same log, one interruption real and one after
> the fact.
