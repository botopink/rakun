# Decision 432 — A `@Task<@Result<T, E>>` is the task that fails with `E`: its Promise rejects with `E` and resolves with `T`; a `@Task<T>` does not fail.

In force with 732's and 523's spelling: the types are `Async<Result<T, E>>` and `Async<T>`. The task methods `map`, `then`, `mapError` and `catch` this row lists are withdrawn: a failing task is read only by `try await … catch` or by `case` on `await`'s `Result`, and composing without awaiting is an `async { … }` block.

The example looks users up for a rakun handler. `buscar` answers `Async<Result<User, LookupError>>`, the task that fails with a `LookupError`: each `throw` fails it, and `return` settles it with the bare `User`. The program reads that task in each of the three ways. `nameOf` writes `try await buscar(id)`, so a failure becomes `nameOf`'s own and its type is again `Async<Result<string, LookupError>>`. `greeting` writes `try await buscar(id) catch User.guest()`, handles the failure on the spot, and answers `Async<string>`, a task that does not fail. `show` writes `await buscar(id)` alone, gets the `Result` back and maps each case to a `Response`. Finally `async { try await nameOf(0) catch "fallback" }` composes a task without awaiting it in place.

The program prints `hello user3`, `hello guest`, `no name`, `fallback`, and the three responses `200 user3`, `404 42` and `503 store down`.

The same task looks the same from the host side. On commonJS a failure rejects the Promise with the `LookupError` value itself and a success resolves with the bare `User`, with no `{ Ok }` / `{ Error }` wrapper, so a JavaScript caller writes `try { await buscar(1) } catch (e) { … }`. On erlang and beam the task's process ends with `{error, E}`, which `await` answers as `Error(e)`. On wasm the scheduler settles the task with the error. A crash inside a task that does not fail is a defect and is contained only by `attempt`.

Cells in this repository that prove it: none yet. rakun's handlers do not yet answer `Async<Response>` (front 150, the request rows of § rakun (5)); the language's own cells for the task's run-time shape are botopink-lang's.

[draft/main.bp](draft/main.bp)
