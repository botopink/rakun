# Decision 260 — `hash.contentHash` folds code points: `contentHash("🎉")` is `djb2([127881])` on every target; the Node cell folds `Array

The example hashes text that holds a codepoint outside the Basic Multilingual Plane. `🎉` is one
codepoint, U+1F389 (127881). `hash.contentHash("🎉")` folds that one number with djb2 and writes the
result in lowercase hex; `djb2Hex([127881])` is the same fold written out in the program, and the
first line prints the hash and `true`. The same text built from its codepoint,
`string.fromCodepoint(127881)`, hashes the same, `true`. The Node host holds the emoji as two UTF-16
units and wasm as four bytes; each folds the codepoints instead, so the hash is one text on every
target. The last line is why rakun cares: rakun-style's `classHash`, which names a component's class,
is the same fold, so a rule holding an emoji gets one class on the server and in the browser.

Proving cells: none in this repository; the hash is std's, proved by botopink-lang's cells, and
rakun-stylesheet's `conformance/rakun-stylesheet/output/stable-hashes` relies on a class derived from
content.

[draft/main.bp](draft/main.bp)
