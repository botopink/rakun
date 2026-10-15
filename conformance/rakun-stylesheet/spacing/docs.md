# Spacing

> Package: [`rakun-stylesheet`](../docs.md) · index: [`../../docs.md`](../../docs.md)

## Pad and Margin

**Nine directions each** — `All`, `X`, `Y`, `T`, `R`, `B`, `L`, and the logical
pair `S`/`E` that follows the writing direction where left and right do not.

{pad/src/main.bp}

CSS has **no `padding-x` property**, so an axis token is two declarations, not
one. Until this front rakun-stylesheet emitted `padding-x:`, `padding-y:` and `margin-y:`
— property names no browser knows, silently discarded — and the `Margin.X`
ladder emitted `m-0.25`, `m-1` and `margin-auto`, which are Tailwind class
fragments rather than declarations. Those eight spellings are gone, and a test
asserts each of them is.

### The scale

Every direction answers the same 35 leaves: the thirty multipliers
`0 1 2 3 4 5 6 7 8 9 10 11 12 14 16 20 24 28 32 36 40 44 48 52 56 60 64 72 80 96`,
the pixel step `Px`, and `Half { 0, 1, 2, 3 }`.

{spacing-scale/src/main.bp}

`0.5` cannot be an enum leaf — a numeric leaf is a run of digits — so `Half.1`
reads "one and a half" and `Half { 0, 1, 2, 3 }` covers `0.5`, `1.5`, `2.5` and
`3.5`. **A spacing value is never resolved here**: every leaf answers
`spacing(n)` or `spacingHalf(n)`, so `--spacing` stays the one place the length
is decided (§ Spacing — `spacing(n)`).

### `Auto` and `Neg`, on margin

`Auto` is a value on the ladder, so it is on **every** margin direction and gets
the same expansion every multiplier gets. `Neg` is upstream's `-mt-4`, the one
family of utilities with no alternative spelling:

{margin-auto-neg/src/main.bp}

`Neg` carries no `0` and no `Auto` — a negative zero and a negative auto are not
utilities — and its `Half` is `{ 0, 1, 2, 3 }`, answered by the theme's
`spacingNegHalf`: `.Margin.T.Neg.Half.0` is `-mt-0.5`,
`margin-top:calc(var(--spacing) * -0.5)`.

## Space — spacing between children

`space-x-*` and `space-y-*` are **not declarations on the element**. They set a
margin on its children, so a `Space` token produces a rule with its own
selector:

{space-between-children/src/main.bp}

Two rules of one class, because they do not describe the same elements. This is
upstream v4's form (verified against `utilities.ts`): the child selector is
wrapped in `:where()` so it adds no specificity, and the gap is split between
the logical START and END margins through the reverse flag — `0` by default, so
the gap sits at the end, and `.Space.XReverse` / `.Space.YReverse` (the flag at
`1`) move it to the start. The scale is the one `Pad` and `Margin` use, `Neg`
included; a zero step is a bare `0` on both sides.

The selector is a nesting template carrying exactly one `&`, so a modifier
wraps it rather than replacing it:

{space-modifier/src/main.bp}

**Recorded, not hidden:** `space-x-*` is absent from the local Tailwind
reference entirely, so the child selector and the properties were read from
upstream's `utilities.ts` (2026-09-26) rather than transcribed, and the
`--tw-space-*-reverse` names are
upstream-internal and unverified. Both are pinned by a test, so changing them
is a visible change.
