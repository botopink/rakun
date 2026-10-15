# size-named-widths

{src/main.bp}

#### The named widths are the theme's, not rakun-stylesheet's

`max-w-md` is `max-width:var(--container-md)` upstream and here. The `rem`
behind each name is written once, in the theme, so a project that redefines
`--container-md` moves every `max-w-md` in the build — which a literal ladder in
the dispatcher would have made impossible.

`MaxW` carries all thirteen container names, `X3xs` and `X2xs` through `X7xl`,
and `MaxW.Screen` the five breakpoints. No `Size` leaf emits a `rem` of its own;
a test walks all 566 of them and asserts it.
