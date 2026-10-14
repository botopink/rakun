# outline-focus-visible

An outline is painted **outside** the border box and **takes no space**, which
is why a focus ring is an outline and not a border: focusing a control moves
nothing beside it.

> **`.Outline.Style.None` is the trap.** It is **not** `outline-style:none`.
> Upstream prints it as a *transparent* outline plus an offset, so a
> high-contrast mode still renders a ring where the design removed one. The
> token sits under `Style` because that is where upstream puts it; only the
> emission is special.

A negative offset is a leaf on a `Neg` sub-section and not a sign on a number,
because a numeric enum leaf is a run of digits.
