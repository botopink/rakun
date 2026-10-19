# Decision 174 — † `Dict.ofEntries(entries: Array<#(K, V)>) -> Dict<K, V>` in `libs/std/src/collections.bp`; a key that repeats keeps its

The example merges two sources of rakun configuration into one table. `cliEntries` reads each set of `--key=value` arguments into rakun's `config.Entry` records. `defaults` comes first and `overrides` after it, so the `Array<Entry>` holds `server.port` twice. `Dict.ofEntries` builds the table from the entries as `#(key, value)` tuples. The key that repeats keeps the value of its last occurrence: `server.port` reads `9090`, the override, and `rakun.web.base-path` reads `/api`. The table holds two keys (`2`). That is the precedence rakun's loader gives a higher source over a lower one.

A table built entry by entry with `insert` comes out the same, so the last line prints `true`: `ofEntries` is a chain of `insert`s. `Set.fromList` and `Queue.fromList` keep their names.

Cells in this repository that prove it: none yet. rakun's configuration cells (`rakun/configuration/config_load`, `rakun/configuration/config_document`) load and apply its sources (`rkConfigLoad`, `readDocument`), and the table built by `Dict.ofEntries` comes into its conformance with front 165 s7, the workspace's Conformance step.

[draft/main.bp](draft/main.bp)
