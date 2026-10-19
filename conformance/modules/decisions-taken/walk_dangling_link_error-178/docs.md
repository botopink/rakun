# Decision 178 — † A dangling link under `fs.walk` is an `Error` naming the link, on both targets — not skipped

The program makes a directory holding one page and a link to a file that does not exist, then walks it — as rakun-ssr walks `app/` and the content directories. `fs.walk` answers an `Error` naming the dangling link, and the program prints its text, `walk-178: fs.walk: dangling link "dangling.md"`; the walk does not skip the link and answer the page alone. The answer is the same on erlang and commonJS.

Cells of this repository that prove it: none yet — the rule is std's (`02/97`); rakun-ssr's `cli/scan.bp` and `cli/build.bp` call `fs.walk`.

[draft/main.bp](draft/main.bp)
