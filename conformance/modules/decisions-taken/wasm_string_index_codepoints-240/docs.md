# Decision 240 — wasm counts a string's index in codepoints, as erlang and beam: `length`, `at`, `slice`, `indexOf`, `lastIndexOf` walk U

The example shortens a page title by index. `"Olá, señor 👋 — ünïcode"` is 22 codepoints, so
`length` is `22`; `at(2)` is `á` and `at(11)` is `👋`, each one codepoint whatever its UTF-8 length;
`indexOf("👋")` is `11` and `lastIndexOf("ü")` is `15`; `shorten(title, 12)` keeps the first eleven
codepoints and adds an ellipsis, `Olá, señor …`. wasm holds the string as UTF-8 and walks its
sequences to answer these, so its numbers are the ones erlang and beam answer; rakun builds for
erlang, and a package of the workspace built for wasm prints the same four lines.

Proving cells: none in this repository; the wasm string is the backend's and std-wasm's, proved by
botopink-lang's `run/string_index_of_codepoints` on the four targets.

[draft/main.bp](draft/main.bp)
