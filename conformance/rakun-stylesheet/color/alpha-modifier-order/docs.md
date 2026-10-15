# alpha-modifier-order

{src/main.bp}

`bg-red-500/50` is a **wrapper**, not a leaf. Opacity cannot hang under the
family — the shade is already the leaf, and a second numeric level would
multiply the grid to 26 × 11 × 21 — and a payload leaf nested inside a section
has no constructible spelling, so `Alpha` is a top-level variant with a
builtin-typed field, the shape `Hover(inner: Token[])` already has.

It rewrites the VALUE of every declaration its inner tokens produce, rule by
rule, so the selector and at-rule of a modifier inside it survive and it
composes in either order:

A **non-colour** token is rewritten too, and the result is meaningless CSS
(`font-weight:color-mix(in oklab, bold 50%, transparent)`). That is
deliberate: dropping the declaration silently would hide the mistake, and one
a browser discards is visible in devtools the moment it is looked for.
