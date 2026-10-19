# Decision 689 — On erlang and beam a spawned child runs behind a port: its stdin is a pipe, not the parent's, and its stderr is merged into stdout; kept and documented in `libs/std/AGENTS.md` and the function's doc.

The child rakun-ssr's `start` runs, seen from inside. One shell script reports what its standard input is, writes a line to stdout and a line to stderr. Run with `io.process.run` on erlang or beam, the child sits behind a port: it reports `stdin: pipe` — the port's, not the parent's terminal — and both of its lines arrive in `stdout`, `stderr` merged in, so `stderr apart` is `false`. Started with `io.process.spawn` and awaited with `wait()`, the same child writes its output through the parent's stdout as it produces it, and the exit status is `0`.

On commonJS the child shares the parent's streams and `stderr` is split out; that difference is kept, and documented in std's `io.process`. A port program that hands the parent's descriptors over is a later step, when a library needs it.

Cells of this repository that prove it: none yet — rakun-ssr's `start` meets it with front 150 s60.

[draft/main.bp](draft/main.bp)
