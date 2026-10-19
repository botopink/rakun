# Decision 704 — No cancellation in std's async: a losing racer and an expired timeout run to completion and their results are dropped; `raceOf` / `timeout` document it.

Two races, both losers left running. `async.raceOf` starts `slow` and `fast`; `fast` answers first and the program prints `won fast`. `async.timeout` gives `report` ten milliseconds; it answers `Error("timeout")` and the program prints `timeout timeout`. Neither loser is stopped: at that moment rakun's context notes (`rkCtxNotes()`) hold nothing, and after a wait long enough for both, they hold `slow ran to completion` and `report ran to completion` — each loser ran to its end and its result was dropped.

There is no cancellation surface: no token, no linked process. The contract of a race is its result and the order of its answers, never the interleaving of its tasks.

Cells of this repository that prove it: none yet — rakun's server races (front 150) rely on it without a cell of their own.

[draft/main.bp](draft/main.bp)
