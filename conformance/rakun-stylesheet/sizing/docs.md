# Sizing

> Package: [`rakun-stylesheet`](../docs.md) · index: [`../../docs.md`](../../docs.md)

## Size

Thirteen sub-sections: `W`, `H`, `Both`, `MinW`, `MaxW`, `MinH`, `MaxH`, and the
six logical forms `Inline`, `Block`, `MinInline`, `MaxInline`, `MinBlock`,
`MaxBlock`. Four kinds of leaf.

{size-kinds/src/main.bp}

`1/2` is neither an identifier nor a run of digits, so a fraction cannot be a
leaf; `Frac` carries the eleven upstream fractions by name — `Half`, `Third`,
`TwoThirds`, `Quarter`, `ThreeQuarters`, `Fifth`, `TwoFifths`, `ThreeFifths`,
`FourFifths`, `Sixth`, `FiveSixths`. Each is upstream v4's `calc(N / D * 100%)`,
spelled once by `fraction(n, d)`, and every `Frac` in the library — sizes,
insets, flex bases, translates — reads it.

**The viewport unit differs by axis** and the tests say so:

{size-viewport/src/main.bp}

`Both` is upstream's `size-*` — two declarations from one leaf:

{size-both/src/main.bp}

### The named widths are the theme's, not rakun-stylesheet's

`max-w-md` is `max-width:var(--container-md)` upstream and here. The `rem`
behind each name is written once, in the theme, so a project that redefines
`--container-md` moves every `max-w-md` in the build — which a literal ladder in
the dispatcher would have made impossible.

{size-named-widths/src/main.bp}

`MaxW` carries all thirteen container names, `X3xs` and `X2xs` through `X7xl`,
and `MaxW.Screen` the five breakpoints. No `Size` leaf emits a `rem` of its own;
a test walks all 566 of them and asserts it.
