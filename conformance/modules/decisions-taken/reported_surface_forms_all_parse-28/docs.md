# Decision 28 — What decision 14 left unassigned

The example is one program that writes every surface form this decision settled, each in a line of rakun code. `built` is a module-level `var`: `respond` bumps it each time it builds a rakun `Response`, and `main` reads it at the end, so the last line printed is `1`. On the BEAM there is no module-level storage of its own, and the value is the process's — the same place rakun keeps the registries `rakun.bp` declares as module-level `var`s (`modules`, `started`, `stops`).

`adder(3)(4)` calls the result of a call and prints `7`. `(respond("hi")).status.toString()` and `("ab").length()` read a member off a parenthesised expression — one production, however the parentheses are filled — and print `200` and `2`. The table of routes is typed `#(path: string, status: i32)[]`, an array of labelled tuples. `routes.at(5)` answers an optional, and `??` gives it a default: the missing sixth route prints `404`, the second `301`. The bare `if` that prints `two routes` is not the last statement of `main`'s block and needs no `;` after it.

The program prints `two routes`, `7`, `200`, `2`, `404`, `301` and `1`.

Cells in this repository that prove it: none yet. The forms are the language's; rakun's sources use each of them (`rakun.bp`'s module-level `var`s, `??` across `config.bp`), and the feature cells that exercise them come with front 165 s7, the workspace's Conformance step.

[draft/main.bp](draft/main.bp)
