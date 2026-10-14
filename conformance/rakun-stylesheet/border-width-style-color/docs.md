# border-width-style-color

### Border — `§ 11.1`–`§ 11.4`

An **axis** is two declarations and a **side** is one, because CSS has no
`border-x-width`. The logical pair `S`/`E` is
`border-inline-start-width`/`-end-width`, which follows the writing direction
where `L`/`R` do not — the same distinction `Pad.S`/`Pad.E` draws.

`Border.Color` carries the whole of [the palette](#color--the-palette): 26
families × 11 shades, plus `White`/`Black`/`Transparent`/`Current`/`Inherit`.
Every cell goes through the same `paletteVar(family, shade)` that `Color`,
`Bg.Color`, `Outline.Color`, `Ring.Color` and `Divide.Color` use, so
`.Border.Color.Emerald.600` and `.Color.Emerald.600` reference **one** custom
property and cannot drift apart.

> **This changed what a compiling path means.** Before front 40 the dispatcher
> DISCARDED the shade — every cell emitted `border-color:red` or
> `border-color:gray`. Three shades of one family were therefore ONE class,
> since the class name is a hash of the body. If you pinned that text, it moved.

`.Border.Color.Hex(value)` is declared and, like every payload leaf nested in a
section, **cannot be constructed** — see
[`Color.Hex` is declared and unconstructible](#colorhexabc-is-declared-and-unconstructible).
