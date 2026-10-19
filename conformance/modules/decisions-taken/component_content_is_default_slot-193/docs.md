# Decision 193 — A component's content is its default slot, read with `<Slot />` (360) — no `children` field in a component's props; the

`Card` takes one prop, `title`, and has no `children` field. Where its markup writes `<Slot />`, the renderer puts whatever the caller wrote between `<Card …>` and `</Card>`, here two paragraphs. That content is a `Node`, the same closed set a hole accepts: text, numbers, components and lists of them. It reaches the card through a hidden argument, so no attribute names it. The program prints the page's HTML as one line, with the card's heading followed by both paragraphs inside its `section`, then the divider.

`Divider` writes no `<Slot />`, so `<Divider label="end" />` is written self-closed. Content between `<Divider …>` and `</Divider>` would be a comptime error at that tag. Named slots (`<Slot name="footer">`, a child annotated `#[slot("footer")]`) are decision 360's.

Cells in this repository that prove it: none yet. `Slot` and the hidden content argument arrive with front 150 s39 step 4 (slots, decision 360). `rakun-bpp/html-dsl/html_dsl_hole` shows the hole types the content shares.

[draft/main.bp](draft/main.bp)
