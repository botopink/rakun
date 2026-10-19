# Decision 707 — rakun's tag epoch only grows (`rkResetContext` leaves the tags table), is an `i64`, and `""` is refused in `rkBumpTag` / `rkTagEpoch` (`rakun: a tag is a non-empty string (rkBumpTag)`).

The program is a cached response kept the way `rakun-restclient` keeps one: `Cached` stores the body beside `rkTagEpoch("users")` read when it was stored, and `fresh` compares that epoch with the tag's current one. A tag never bumped is at `0`, so the entry starts fresh (`0`, `true`). `rkBumpTag("users")` — what `rakun-cache`'s revalidation verbs call — answers the new epoch, an `i64`, and the stored entry is now a miss (`1`, `false`). `rkResetContext()` drops the scan registry, the routes and the fallback, but it leaves the tags table: the epoch is still `1` and the entry is still a miss, because an epoch never goes back and so no epoch stored before a bump can ever match a later state. The next bump answers `2`. A tag is a non-empty string: `rkBumpTag("")` or `rkTagEpoch("")` stops the program with `rakun: a tag is a non-empty string (rkBumpTag)` — an empty tag is the caller's bug, not a tag of its own.

Cells in this repository that prove it: none yet. The epoch is tested in `modules/rakun/test/erlang_runtime_test.bp`; its cell comes with front 150's Conformance step (decision 465).

[draft/main.bp](draft/main.bp)
