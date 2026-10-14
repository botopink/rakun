# gradient-direction

### Gradient — `§ 10.4`

Gradients are their own top-level section, not a sub-section of `Bg`. The stop
colours are not `background-image` at all — they are custom properties the
gradient reads — so nesting them under `Bg.Image` would put three properties
under one name; and a stop is a four-segment path already.

**`To` is the direction. `Stop` is the terminal colour.** Tailwind spells both
with the word `to` (`bg-gradient-to-r` and `to-pink-500`) while they set
unrelated things; emilia does not.

A corner is **two keywords** — `to top right`, never `to top-right` — and there
is exactly one space after the comma. The eight phrases are spelled in one
place in `emilia.bp`, so adding a direction is one arm.
