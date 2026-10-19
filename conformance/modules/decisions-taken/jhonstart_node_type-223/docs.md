# Decision 223 — jhonstart's node type — what a slot holds and what a hole accepts (191) — is `Node`, imported `import {Node} from "jhons

The example builds a card whose slot is typed with the one name for what a slot holds and what a
hole accepts: `Node`, imported from `rakun-bpp` beside `html` and `Element`. `Card` declares
`children: Node` and places it with `${children}`; the three calls hand it a plain string, a list
of `Element`s built by `item`, and a number, and each renders: `Hello`, the two `<li>`s, `42`. The
helper `pick` answers `Node` too, so a value chosen at run time between a text and an element still
fits the slot without a wrapper.

No other name is written for the set: the old `JhonstartNode` and `Children` spellings appear
nowhere, and a consumer that needs the type imports `Node` and nothing else.

Proving cells: none in this repository yet; the rakun-bpp builders still take `Children`
(`modules/rakun-bpp/src/node.bp` says so), and the cells that write `Node` come with front 118 and
the rakun-bpp Conformance step (465).

[draft/main.bp](draft/main.bp)
