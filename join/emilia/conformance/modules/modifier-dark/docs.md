# modifier-dark

### Modifiers — the variant table

A modifier is the only way a token reaches a state, a breakpoint or a
pseudo-element. Each one carries a `Token[]` payload and is **not** a block
nested inside the class body — it is a `Variant` (an at-rule and a selector
template with exactly one `&`), and the tokens it carries become **sibling
rules** hoisted out of the class with their own selector and at-rule.

Modifiers nest, and the OUTER one is outermost in the selector and in the
at-rule list alike — which is how a `dark:md:hover:` chain reads upstream:
