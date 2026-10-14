The five views of the route are hooks, spelled as nouns: `router`, `pathname`,
`params`, `searchParams`, `selectedLayoutSegment` and `selectedLayoutSegments`.
Each is one read of the snapshot. A component activates them with `use`; called
without `use` they answer the same value, so `await params()` reads the
parameters and `pairValue(ps, "slug")` picks one.
