# Decision 259 — wasm's `std/math` agrees with commonJS bit for bit, `pow` included: std ports glibc's `pow` (the algorithm since glibc 2

Three powers through `math.pow`, std's own botopink body ported from glibc. The first line is `1896229.4525711867` on every target — the pair where the hosts' `pow` disagreed by one bit —, then `2` to the half and `10` to the minus three, each the same bits everywhere.

Cells of this repository that prove it: none — the rule is std's (`05-wasm`); a rakun computation over `f64` reads it through std.

[draft/main.bp](draft/main.bp)
