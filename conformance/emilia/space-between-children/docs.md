# space-between-children

### Space — spacing between children

`space-x-*` and `space-y-*` are **not declarations on the element**. They set a
margin on its children, so a `Space` token produces a rule with its own
selector:

Two rules of one class, because they do not describe the same elements. This is
upstream v4's form (verified against `utilities.ts`): the child selector is
wrapped in `:where()` so it adds no specificity, and the gap is split between
the logical START and END margins through the reverse flag — `0` by default, so
the gap sits at the end, and `.Space.XReverse` / `.Space.YReverse` (the flag at
`1`) move it to the start. The scale is the one `Pad` and `Margin` use, `Neg`
included; a zero step is a bare `0` on both sides.

The selector is a nesting template carrying exactly one `&`, so a modifier
wraps it rather than replacing it:
