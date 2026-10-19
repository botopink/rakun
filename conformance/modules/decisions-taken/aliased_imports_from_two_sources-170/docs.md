# Decision 170 — std takes the natural name and a library's copy goes (`clock.parseDuration`, `async.RetryPolicy`, `async.nextDelay`; rak

Two declarations named `matches` meet in one module: rakun's `profiles.matches`, which evaluates a profile expression against the active profiles, and std's `regex.matches`. Each import names its source and takes an alias, `profileMatches` from `"rakun"` and `patternMatches` from `"std"`, so every use says which declaration it means and none is ambiguous. `profileMatches("prod & !dev", ["prod", "eu"])` prints `true` and `profileMatches("dev | test", …)` prints `false`. `patternMatches("^/api/", "/api/users")` prints `true` and `patternMatches("^/api/", "/health")` prints `false`.

What stays refused is a use that cannot tell the two apart: writing both imports without aliases, which binds `matches` twice, or reaching a bare `matches` that two declarations answer.

The other half of the decision is a rule for the library. When std has the natural name, rakun's copy goes. `config.parseDuration` and the retry helpers are rakun's copies of std's `clock.parseDuration`, `async.RetryPolicy` and `async.nextDelay`, and rakun deletes them in its "consume std" steps, so the example does not use them.

Cells in this repository that prove it: none yet. The import rule is the checker's. rakun's cells that import two packages side by side come with front 165 s7, the workspace's Conformance step, and the removal of rakun's copies is front 150's.

[draft/main.bp](draft/main.bp)
