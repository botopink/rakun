# Decision 262 — A primitive `String.fromCodepoint(cp: i32) -> string` in `primitives.bp` (Node `String.fromCodePoint`, erlang `<<Cp/utf8

The example builds the text of a rakun-bpp paragraph from Unicode code points. `word` maps each `i32` through `String.fromCodepoint` and joins the one-character strings. `[79, 108, 225]` is `Olá`, whose last letter takes two UTF-8 bytes. `[8364, 32, 53]` is `€ 5`, which starts with a three-byte character. `127881` is the four-byte 🎉.

rakun-bpp renders the text nodes as they are, so the first line prints `<p>Olá 🎉</p>`. The second line prints `€ 5` and its length in code points, `3`. The last line reads a code point back with `charCodeAt` and turns it into a string again, which prints `true`.

The primitive is the same on every target: Node's `String.fromCodePoint`, erlang's `<<Cp/utf8>>`, and std-wasm's `str_from_cp`. std's `unicode`, `encoding` and `querystring` build their text with it on wasm.

Cells in this repository that prove it: none yet. rakun-bpp's component cells (`rakun-bpp/components/`) render literal text only, and code-point text comes into its conformance with front 165 s7, the workspace's Conformance step.

[draft/main.bp](draft/main.bp)
