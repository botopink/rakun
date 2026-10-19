# Decision 401 — emilia adds negative translate and named groups / peers; the named `has` / `not` / ARIA / data / `in` variants and `@theme inline` stay deviations, written with `arbSel`.

The example uses the two additions and one deviation in one card. The link's tokens hold
`.GroupNamed("card", [.GroupHover([.Text.Underline])])` — Tailwind's `group-hover/card:underline` —
whose rule is `.group\/card:hover .e_…{text-decoration-line:underline}`, so the link underlines while
the card marked `group/card` is hovered, and `.Transform.TranslateY.Neg.__2`, Tailwind's
`-translate-y-2`, which writes `--tw-translate-y:calc(var(--spacing) * -2)` and the composed
`translate`: a negative translate is the `Neg` sub-section, like `Rotate.Neg`. The paragraph's
`.PeerNamed("agree", [.PeerChecked([.Text.Bold])])` is `peer-checked/agree:font-bold`, keyed to the
checkbox marked `peer/agree`. The section needs `has-[img]:p-2`: the named `:has()` form is a
deviation, written with `arbSel("&:has(img)", …)` and the selector spelled out, as are `:not()`,
ARIA, data-attribute and `in-[…]`; `@theme inline` has no token at all. Each rule is measured
against Tailwind 4.3.2's output.

Proving cells: `conformance/rakun-stylesheet/modifiers/named-groups` (named groups and peers),
`conformance/rakun-stylesheet/escape-hatches/deviations-arbsel` (the `arbSel` deviations), both in
today's run-time spelling; the negative translate's values are listed in
`conformance/rakun-stylesheet/motion/docs.md`.

[draft/main.bp](draft/main.bp)
