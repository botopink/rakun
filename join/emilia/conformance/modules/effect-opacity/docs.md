# effect-opacity

#### Opacity

Twenty-one steps, each upstream v4's **percentage** — `opacity:60%`, where the
reference prints the v3 fraction `opacity:0.6`.

A numeric leaf is three spellings for one thing: bare digits in the
declaration, `.Effect.Opacity.60` in expression position, `__60` in a `case`
pattern.

`§ 12.3` prints fifteen steps. Six more — `15`, `35`, `45`, `55`, `65`, `85` —
are declared and confirmed against upstream's compiled `opacity-<n>`, which the
reference carries no row for.
