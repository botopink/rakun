# Decision 314 — A numeric enum leaf has no sign; a negative value is a `Neg { … }` sub-section.

The example writes rakun-stylesheet tokens whose Tailwind names carry a minus sign. `rotate-12` is
`.Transform.Rotate.__12`, the numeric leaf spelled `__12` in expression position; `-rotate-12` is
not a signed leaf but the `Neg` sub-section, `.Transform.Rotate.Neg.__12`, read "rotate, negative,
twelve". The two compute different classes, `true`. `rotation` matches the same leaves in pattern
position, one section at a time — `__12`, then `Neg(n)` and inside it `__12` — and prints
`rotate -12deg rotate 12deg`; the badge carries `.Margin.T.Neg.__4` (Tailwind's `-mt-4`) and
`.Transform.Rotate.Neg.__12` on one tag. There is no `.__N12` and no unary `-` on an enum path: the enum would read
`Rotate { 12, -12 }`, which is a parse error at the `-`, so the sub-section is the language's form,
the one `Margin.*.Neg`, `Ring.Offset.Neg` and `TranslateX.Neg` follow.

Proving cells: `conformance/rakun-stylesheet/spacing/margin-auto-neg` (`Margin.*.Neg`) and the
`Neg` rows of `conformance/rakun-stylesheet/motion/docs.md`.

[draft/main.bp](draft/main.bp)
