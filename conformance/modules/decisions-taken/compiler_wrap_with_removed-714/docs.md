# Decision 714 — `compiler.wrapWith` goes: a decorator never changes what a call does without the caller seeing it; behaviour around a function is a proxy type the decorator builds or a function written around the call.

The example puts behaviour around calls in the two forms that remain, both visible where the call is
written. rakun-data's `#[transactional]` on `OrderService` builds a proxy type, `OrderService.Tx`,
whose `place` runs the plain `OrderService.place` inside a transaction. The decorator changes nothing
about `OrderService` itself: `main` writes `OrderService.Tx.make().place(120)` to take the
transactional path, and a caller that writes `OrderService.make().place(…)` gets the bare one — the
difference is in the caller's text.

Around one function, the program writes a function around the call. `withAttempts(3, { -> notify()
})` retries the notification until it answers `Ok`; `notify` fails twice and succeeds on the third
call, so `main` prints `sent after 3`. There is no `compiler.wrapWith`: a decorator on `notify` could
not make its calls retry without the caller seeing it.

Proving cells: none in this repository yet; rakun-data's `#[transactional]` proxy is front 08 step 6's,
its cells and rakun's `#[retryable]` as a function around the call coming with 150 s29.

[draft/main.bp](draft/main.bp)
