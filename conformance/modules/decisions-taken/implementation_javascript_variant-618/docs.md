# Decision 618 — `Implementation.Node` is renamed `JavaScript`: a source names the language the template is written in, not a runtime.

`encodeSegment` percent-encodes one path segment with each host's own function. Its JavaScript source is written `.JavaScript("encodeURIComponent($0)")`, naming the language the template is written in, and the erlang and beam targets share `.Erlang("uri_string:quote($0)")`. The program prints `/search/rakun%20bpp` on each of the three targets the cell runs on. There is no `.Node(…)` variant: every source a library writes for the commonJS target is a `.JavaScript(…)`, as in rakun-bpp's `modules/rakun-bpp/src/globals.bp` and `modules/rakun-bpp/src/error_boundary.bp`. The `Typescript` variant and a `types:` field do not exist either.

Cells in this repository that prove it: none yet. rakun-bpp's render tests (`modules/jhonstart-dom-test/src/root.bp`, `.JavaScript(…)` only) build on this form; the cells come with front 165 s10.

[draft/main.bp](draft/main.bp)
