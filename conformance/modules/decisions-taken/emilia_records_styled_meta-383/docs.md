# Decision 383 — `#[emilia(…)]` records `styled`'s `StyledMeta(layer: Layer, className: string, rules: string)`, one per tag.

The example puts two recorded styles on one link. `#[emilia(.Pad.X.__4, .Text.Underline)]` computes
its class and rules at build and records them as rakun-style's `StyledMeta`, with the layer
`.Utilities` — `setMeta`, one value per tag, so a second `#[emilia]` on the same tag would be
refused there and the tokens go in one list, whose order is the class. `outline` is a style
decorator of the program's own: it records the same type, `StyledMeta`, in the layer `.Components`.
rakun-bpp's `html` reads the meta by its type, not by who wrote it, and merges each `className`
into the link's `class` in annotation order, so the markup prints `class="e_… ol_2"`; the render's
sink writes each meta's `rules` in that meta's layer, so the stylesheet shows the emilia rule and
`.ol_2{outline-width:2px}` in their layers. Neither rakun-bpp nor rakun-style names emilia.

Proving cells: none in this repository yet; the typed meta comes with `01-compiler/130` step 8, the
reading with `08-bpp/119` step 4 and the recording with `06-emilia/34` step 5.

[draft/main.bp](draft/main.bp)
