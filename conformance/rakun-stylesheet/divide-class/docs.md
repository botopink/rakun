# divide-class

`divide-*` declares on the element's **children**, not on the element — a
border on every child but the last — so the class body itself is **empty**:

A width, a colour and a style all target the **same** selector, so they merge
into one child rule rather than three.

That selector is the same one [`Space`](#space--spacing-between-children) uses,
and it is spelled in exactly one place in the library — `siblingSelector()`.
`divide-*` and `space-y-*` separate the same children, and a test compares the
two families' output **byte for byte** so that the two can never be written
differently.

`examples/emilia-outline-ring/` is the worked example for all three sections.
