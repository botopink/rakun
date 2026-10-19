# Decision 350 — emilia renders what Tailwind 4.3.2 compiles, as close as it can, written with `styled` (338).

`rakun-stylesheet` (emilia's package now) takes upstream's compiled CSS as its reference. The program asks it for three families whose shapes Tailwind 4.3.2 fixes, and each answers upstream's form. `w-1/2` (`.Size.W.Frac.Half`) is `width: calc(1 / 2 * 100%)`, never a rounded percentage. `opacity-60` is `opacity: 60%`. `-rotate-12` (`.Transform.Rotate.Neg.__12`) is `rotate: calc(12deg * -1)`. Each family uses one helper for its shape, so no family mixes two conventions.

A family is written with `rakun-style`'s literal in Tailwind's own CSS syntax. `padAll` is `` styledProperty @`padding: --spacing(${n});` ``, with upstream's `@utility p-*` quoted beside it, so parity is read off the literal. The last line compares `padAll(4)`'s declarations, computed at build, with the `p-4` output quoted from 4.3.2, and prints `true`.

The five families still out of parity move under the same rule: the transition presets, `backdrop-opacity-*`, `-webkit-backdrop-filter`, `border-spacing-*` and `divide-*`'s border style. Each new literal is asserted against 4.3.2's output quoted in its test.

Cells in this repository that prove it: `rakun-stylesheet/sizing/size-kinds` (the fraction shape) and `rakun-stylesheet/effects/effect-opacity` (the opacity shape), and `rakun-stylesheet/getting-started/own-utilities` shows a family of the application's own. The move of the families into `styled`'s literal is front 150 s52, then s53.

[draft/main.bp](draft/main.bp)
