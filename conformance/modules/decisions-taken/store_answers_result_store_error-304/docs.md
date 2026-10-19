# Decision 304 — A store has one API, answering `@Result<T, StoreError>`; no `try*` twin and no raise on a driver failure.

`SqlTemplate.query` and `update` of `rakun-data` answer a `Result` whose error is `StoreError`, the enum rakun-data shares between SQL and NoSQL — `Unavailable(message)`, `Timeout(ms)`, `Conflict(message)`, `Constraint(name, message)`. The handler `countUsers` propagates it with `try` and answers `Result<Response, StoreError>`, which rakun's web layer turns into a status (`Unavailable` 503, `Conflict` 409, anything else 500 with a digest). `describe` matches every case. `main` points the template at a data source that is not configured, so the driver failure comes back as a value from both calls and the program prints the `StoreError`'s description twice — nothing raises.

There is no `tryQuery`, `tryUpdate` or other `try*` twin: one method, one answer. A panic stays for a programming error only, such as `single()` meeting two rows.

Cells of this repository that prove it: none yet. rakun-data's `SqlTemplate.query` still answers `Rows` and raises on a driver failure, beside `tryQuery` / `tryUpdate` answering `Result<…, string>` (`modules/rakun-data/src/sql/template.bp`); `StoreError` is rakun 08 s6's and 09 s6's.

[draft/main.bp](draft/main.bp)
