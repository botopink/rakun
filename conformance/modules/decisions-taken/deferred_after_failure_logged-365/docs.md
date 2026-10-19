# Decision 365 — A deferred `after()` failure reaching the core's logger is front 17's step, not 128's.

The example is an order request whose deferred work fails. The handler schedules `sendReceipt` with `after(…)`, so the work runs once the response is on the wire, and the work raises. When the dispatcher's `endRequest()` and `drainAfter(30000)` reap it, rakun counts one failure (`afterFailed()` prints `1`) and keeps the request's own record, where `afterLog()` names the request `req-9`.

The failure is not left in that record alone. `drainAfter` also writes it through the core logger, on the logger `rakun.request.after`, as an error line `after: failed <id> <reason>`, with the request id `req-9` as the line's correlation id. The program captures the console handler around the request and finds the logger's name, the `after: failed` text and the request id in what was written, so it prints `1`, `true`, `true true` and `true`. A deferred function that overruns its budget is reported the same way. A failure that never reached the logger would be invisible in production, which is why the report through the logger is never dropped.

Cells in this repository that prove it: `rakun/request-context/request_after` (the counters and `afterLog()`, not yet the logger line). The line through `logger("rakun.request.after")` comes with front 150's step for the former `04-rakun/17` step 4, and until it lands the checks on the captured lines print `false`.

[draft/main.bp](draft/main.bp)
