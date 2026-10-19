# Decision 303 — An action answers `@Result`; there is no `ActionOutcome`.

In force with 732's spelling: the return type is `Async<Result<Subscribed, ActionError>>`, the action an `async fn`.

The example is a newsletter signup registered with rakun-app's `#[action]`. Its input is the `#[validated]` record `Signup`, and its body is that of any asynchronous function that can fail: `return Subscribed(email: …)` is the `Ok`, and each `throw` is an `Error` value of `actions`' sum type `ActionError`, here `Unauthorized` when the context holds no session and `Conflict` for an address already on the list. Every case is an HTTP status on the wire (`Input`, `BadRequest`, `Unauthorized`, `Forbidden`, `NotFound`, `Conflict`, `TooManyRequests`, `Internal`).

`main` calls the action twice over. `callAction` goes through the wrapper, the way a form post does, and answers the same `Result<Subscribed, ActionError>` the function answers. When the pairs do not make a valid `Signup`, the wrapper answers `Error(Input(fields))` itself and the body never runs. A direct call, `await signup(…)`, gets the same type back. `show` reads both with one `case`, so the program prints `subscribed ana@example.com`, `check email`, `401 User must be logged in.` and `409 Already subscribed.` There is no `ActionOutcome` record, no `ActionErrorCode` and no `orError()`, and the `{data}` / `{error}` JSON envelope that carries the answer to the browser never appears in this code.

Cells in this repository that prove it: none yet. `modules/rakun-app/src/actions.bp` still declares `ActionOutcome` and `#[serverAction]`; `#[action]`, `ActionContext` and `callAction` over `actions`' `ActionError` come with front 150 s23 (127 s1–s3), and until then the example does not build.

[draft/main.bp](draft/main.bp)
