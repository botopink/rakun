# Decision 263 — `std/math` answers the same bits on every target and OS: its transcendental functions call std's private botopink bodies

The program prints `sin`, `tan`, `exp`, `log10` and `pow` — std's private bodies, the fdlibm port, on erlang and beam as on commonJS and wasm — then `sqrt`, an IEEE-exact host call, and a backoff curve of the kind a retry policy computes from `exp` and `floor`. Every line is the same bits on every target and OS.

Cells of this repository that prove it: none — the rule is std's (`02-erlang`, `03-beam`, `05-wasm`).

[draft/main.bp](draft/main.bp)
