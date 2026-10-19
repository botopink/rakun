# Decision 241 — `io/clock.offsetMinutes`, `io/fs.workingDir` and `io/fs.scratchDir` have no wasm binding, so under 146 `io/clock` and `i

This is the refused program, built for wasm. It reads the two things rakun's boot reads from its host. rakun's logging stamps a line with the clock's local offset, `clock.offsetMinutes(now)`, and its config loader looks for a file relative to the working directory, `fs.exists("config/application.json")`. WASI defines neither a local time zone nor a working directory, and neither `io/clock`'s offset nor `io/fs`'s `workingDir` and `scratchDir` has a wasm binding. So on wasm the program is refused. Each call that reaches a host function with no `.Wasm(…)` implementation is a located `std-unsupported-on-target`, and no value is invented: no `0` offset and no `/` directory.

On erlang and beam the same program runs. It prints the host's offset in minutes and whether the file exists. That is where rakun runs: it is erlang-only (decision 113), so none of its packages is built for wasm, and this refusal is what keeps a library built for every target from quietly answering a made-up clock or directory there. Which directory a wasm program sees comes back with a later restructuring of std.

Cells in this repository that prove it: none. rakun builds for no wasm target. The refusal is the wasm backend's and std's.

[draft/main.bp](draft/main.bp)
