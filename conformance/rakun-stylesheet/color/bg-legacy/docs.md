# bg-legacy

{src/main.bp}

Same 26 families, same eleven shades, one property along — and **all 286 cells
resolve**, because `Bg` is a head segment no other enum carries. It is the way
to reach the six shades `.Color.Red` / `.Color.Gray` cannot.

The property is `background-color` and not `background`. Upstream's `bg-*`
colour utilities set the longhand; the shorthand the v0 stub emitted resets
every other background property of the element as a side effect.

The four **legacy** `Bg` leaves keep what they emitted before the palette
landed, so nothing that compiled changed meaning. Front 39 did **not** fold
them in: they still emit the `background` shorthand, and changing what a
compiling path means is not something a front does to another front's surface.
Reach for `.Bg.Color.*` in new code.
