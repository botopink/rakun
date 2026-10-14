# space-modifier

Two rules of one class, because they do not describe the same elements. This is
upstream v4's form (verified against `utilities.ts`): the child selector is
wrapped in `:where()` so it adds no specificity, and the gap is split between
the logical START and END margins through the reverse flag — `0` by default, so
the gap sits at the end, and `.Space.XReverse` / `.Space.YReverse` (the flag at
`1`) move it to the start. The scale is the one `Pad` and `Margin` use, `Neg`
included; a zero step is a bare `0` on both sides.

The selector is a nesting template carrying exactly one `&`, so a modifier
wraps it rather than replacing it:

**Recorded, not hidden:** `space-x-*` is absent from the local Tailwind
reference entirely, so the child selector and the properties were read from
upstream's `utilities.ts` (2026-09-26) rather than transcribed, and the
`--tw-space-*-reverse` names are
upstream-internal and unverified. Both are pinned by a test, so changing them
is a visible change.
