# Borders

> Package: [`rakun-stylesheet`](../docs.md) · index: [`../../docs.md`](../../docs.md)

## Border — `§ 11.1`–`§ 11.4`

{border-width-style-color/src/main.bp}

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

### Border radius — `§ 11.1`, `§ 21.5`

{border-radius/src/main.bp}

Ten leaves — `None`, `Xs`, `Sm`, `Md`, `Lg`, `Xl`, `X2xl`, `X3xl`, `X4xl`,
`Full` — on the shorthand **and on each of fourteen directional sub-sections**:
the four sides `T`/`R`/`B`/`L`, the four physical corners `Tl`/`Tr`/`Br`/`Bl`,
and the six logical ones `S`/`E`/`Ss`/`Se`/`Es`/`Ee`. A **side** form emits two
corner properties and a **corner** form emits one, so `.Border.Rounded.Tl.Full`
is as much a path as `.Border.Rounded.Tl.Lg` is.

> **This changed too.** `Sm`, `Md` and `Lg` used to resolve a literal `rem`;
> they reference `var(--radius-*)` now, so overriding `--radius-lg` moves every
> rounded corner. `Full` and `None` do **not** change — upstream prints those two
> literally, and neither is a theme entry.

`examples/emilia-borders/` is the worked example: one width per side, the two
axes, the six styles, the palette with its shade, and a table-like card with a
rounded top, a square bottom and a dashed internal rule.

## Outline — `§ 11.5`–`§ 11.8`

{outline/src/main.bp}

An outline is painted **outside** the border box and **takes no space**, which
is why a focus ring is an outline and not a border: focusing a control moves
nothing beside it.

{outline-focus-visible/src/main.bp}

> **`.Outline.Style.None` is the trap.** It is **not** `outline-style:none`.
> Upstream prints it as a *transparent* outline plus an offset, so a
> high-contrast mode still renders a ring where the design removed one. The
> token sits under `Style` because that is where upstream puts it; only the
> emission is special.

A negative offset is a leaf on a `Neg` sub-section and not a sign on a number,
because a numeric enum leaf is a run of digits.

## Ring — the box-shadow half of a focus ring

**Every shadow and ring token writes ONE channel and the same reader**, upstream
v4's five-channel `box-shadow`:
`var(--tw-inset-shadow, 0 0 transparent), var(--tw-inset-ring-shadow, 0 0 transparent), var(--tw-ring-offset-shadow, 0 0 transparent), var(--tw-ring-shadow, 0 0 transparent), var(--tw-shadow, 0 0 transparent)`.
So `[.Ring.W.2, .Effect.Shadow.Md]` draws both — and a lone ring draws at all:
each channel falls back to a null shadow, where an unset channel would otherwise
invalidate the whole declaration.

{ring/src/main.bp}

A ring **composes with a shadow rather than overwriting it**: the `box-shadow`
declaration *lists* `var(--tw-shadow)` instead of writing a shadow of its own,
so a `Ring` token and an `Effect.Shadow` token in the same list both reach the
output. Token order is class identity, so swapping the two is a different class
— which is the sharpest case [contract 4](#stable-hashes--sites-collapse) has.

`.Ring.W.1` is upstream's bare `ring`. **The v4 default is 1px**, where v3's was
3px.

> **Verified and unverified.** The custom property names, the inset flag and the
> v4 default width were checked against upstream. The composed `box-shadow`
> list and the whole `ring-offset-*` family were **not** confirmed — v4's
> documentation no longer carries `ring-offset-*` at all. Both are declared
> because the surface asks for them, and both are recorded here rather than
> presented as transcribed.

## Divide — borders between children

{divide/src/main.bp}

`divide-*` declares on the element's **children**, not on the element — a
border on every child but the last — so the class body itself is **empty**:

{divide-class/src/main.bp}

A width, a colour and a style all target the **same** selector, so they merge
into one child rule rather than three.

That selector is the same one [`Space`](#space--spacing-between-children) uses,
and it is spelled in exactly one place in the library — `siblingSelector()`.
`divide-*` and `space-y-*` separate the same children, and a test compares the
two families' output **byte for byte** so that the two can never be written
differently.

`examples/emilia-outline-ring/` is the worked example for all three sections.

### Nothing in `Border`, `Outline`, `Ring` or `Divide` resolves a colour or a radius

The four sections declare **1704 leaves** (492 + 310 + 593 + 309), and a test
walks every one of them asserting the declaration carries no `rem`, no hex and
no colour function; carries a `:`; and carries no Tailwind class fragment. Each
walk has a control that must fail, and one further walk asserts that all 1440
colour cells carry a `var(--color-` reference and that a section's 288 are 288
**distinct** strings — because a literal probe alone does not catch a dispatcher
that discards its shade, which is exactly the defect this section used to have.
