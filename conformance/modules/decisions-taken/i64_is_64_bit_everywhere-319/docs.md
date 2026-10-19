# Decision 319 — `i64` is a real 64-bit integer on every target.

A content length past JavaScript's safe integers: `contentLength(4503599627370497, 2)` multiplies two `i64`s into `9007199254740994`, beyond 2^53, and the program puts it in the body of a rakun `Response`. Every target prints the same digits — `9007199254740994`, then `9007199254740995` for `total + 1` — and the equality with the literal holds: on commonJS a value past the safe range is a `BigInt` in its one canonical form, a small one a plain number, so `==` needs no conversion. `max` is `i64`'s top, `9223372036854775807`, printed exactly; parsing one past it answers `Error`, so the last line is `past i64`.

An integer literal past its type's range is refused by the checker on every target; a conversion to a narrower type aborts rather than rounds.

Cells of this repository that prove it: none yet. rakun's sizes and counters are `i32`; the shared cells of `02-erlang` and `03-beam` are botopink-lang's.

[draft/main.bp](draft/main.bp)
