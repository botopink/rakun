# flex-value-basis-order

#### The shorthand, grow, shrink, basis and order

The sub-section is `Value` and not `Flex`, because a section cannot carry a
sub-section of its own name.

`Basis` is the only family here that is a **length**, and it is front 35's
scale answering front 54's `spacing(n)` / `spacingHalf(n)` — `.Flex.Basis.4`
and `.Pad.All.4` carry the same length text because they call the same
function. Its fractions are front 35's `fraction(n, d)` strings, and a
test compares `.Flex.Basis.Frac.Third` to `.Size.W.Frac.Third` rather than to a
literal.

`Grow`, `Shrink` and `Order` are **bare numbers**: `order-1` is `order:1`, a
count and not a length, so nothing in them reaches the theme. `order-first`
and `order-last` are the sentinels `-9999` and `9999`, and `order-none` is `0`.
