# effect-shadow

{src/main.bp}

#### Shadows

A leaf may not start with a digit, so upstream's `2xs` and `2xl` are spelled
`X2xs` and `X2xl`. The **emitted variable keeps upstream's name** —
`--shadow-2xs`, not `--shadow-x2xs`.

An **inset shadow is not a longhand**. CSS has no `inset-box-shadow`; the
property is `box-shadow` and `inset` leads the value. `.Effect.InsetShadow.Sm`
and `.Effect.Shadow.Sm` therefore set the same property, and the later token in
a list wins.

`Shadow.Inner` is the **one literal in the whole section**. Upstream has no
`--shadow-inner` variable and `§ 12.1` prints the value inline, so writing it
as a theme lookup would invent a variable the reference does not have. Every
other step of every scale is a `var(…)` reference — a test walks all 102 leaves
asserting exactly one of them resolves a shadow value, and asserts from the
other side that the one is `Shadow.Inner`.

> **The stock theme carries `--shadow-*` and neither of the other two.**
> `--inset-shadow-*` is a real `Ns` namespace and a project adds its three
> entries through `extendTheme`. `--text-shadow-*` is **not** an `Ns`
> namespace — front 54's nineteen do not include it — so those entries are
> accepted under the `--text-` prefix instead, which is where `namespace(th,
> Ns.Text)` finds them and where `clearNamespace(th, Ns.Text)` would drop
> them. A real `Ns.TextShadow` is front 54's to add.
