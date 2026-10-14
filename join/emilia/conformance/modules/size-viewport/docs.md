# size-viewport

`1/2` is neither an identifier nor a run of digits, so a fraction cannot be a
leaf; `Frac` carries the eleven upstream fractions by name — `Half`, `Third`,
`TwoThirds`, `Quarter`, `ThreeQuarters`, `Fifth`, `TwoFifths`, `ThreeFifths`,
`FourFifths`, `Sixth`, `FiveSixths`. Each is upstream v4's `calc(N / D * 100%)`,
spelled once by `fraction(n, d)`, and every `Frac` in the library — sizes,
insets, flex bases, translates — reads it.

**The viewport unit differs by axis** and the tests say so:

`Both` is upstream's `size-*` — two declarations from one leaf:
