# Decision 346 — A `Bytes` primitive:

The example receives uploads the way a rakun handler does: an `Upload` holds its content as `bytes`
from the moment it enters. `bytes.fromUtf8("olá")` is four bytes — `á` takes two — so `length` is `4`,
and `describe` reads them back with `toUtf8()`, an `Ok`, answering `note.txt: 3 characters`. The
second upload is `GIF` followed by the first byte of `á` alone, which is no UTF-8: it stays a
`bytes` value, and only the attempt to read it as text answers `Error`, so the handler answers `400`.
`==` compares the bytes, `true`. Nothing converts between `bytes` and `string` but those two calls:
`val b: bytes = "a";` is a type mismatch, and no string ever carries raw bytes.

Proving cells: none in this repository yet; the primitive is the compiler's and std's, and rakun's
binary payloads (uploads, downloads, socket reads; rakun 01, 13, 15, 24, 25, 70, 71) come with their
fronts.

[draft/main.bp](draft/main.bp)
