# layout-columns-box

#### Multi-column, fragmentation, box-sizing

A column **count** is a plain integer. A column **width** is the theme's
container ladder — `.Layout.Columns.Md` and `.Size.MaxW.Md` are the same width
by definition, so they are the same reference, and a project that overrides
`--container-md` moves both. No `Columns` leaf spells a `rem`.

`break-inside` carries a shorter leaf set than `break-after` / `break-before`:
`§ 5.5` has no `all`, no `page`, no `left` and no `right`.

The three are **flat sub-sections**, not `Break { After, Before, Inside }`. A
section head named like a top-level modifier variant silently shadows that
variant's payload, and `After`/`Before` are modifiers — see `AGENTS.md`
§ Maintainer rules.

**Not declared:** `columns-4` … `columns-12`, which resolve upstream through the
bare-integer rule rather than through a theme key; arbitrary `aspect-[4/3]` and
`z-[999]`, which belong to the escape-hatch front.
