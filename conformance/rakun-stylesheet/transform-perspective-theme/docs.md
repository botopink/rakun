# transform-perspective-theme

#### Perspective — a theme namespace

| token | CSS | theme entry |
|---|---|---|
| `.Transform.Perspective.None` | `perspective:none` | — (a CSS keyword) |
| `.Transform.Perspective.Dramatic` | `perspective:var(--perspective-dramatic)` | `100px` |
| `.Transform.Perspective.Near` | `perspective:var(--perspective-near)` | `300px` |
| `.Transform.Perspective.Normal` | `perspective:var(--perspective-normal)` | `500px` |
| `.Transform.Perspective.Midrange` | `perspective:var(--perspective-midrange)` | `800px` |
| `.Transform.Perspective.Distant` | `perspective:var(--perspective-distant)` | `1200px` |

`defaultTheme()` does not carry the namespace, so compose it:

Like front 44's `--ease-*`, **none of these five values is provisional**:
`§ 16.2` prints the variable *and* its length on every row.
`.Transform.PerspectiveOrigin.{Center,Top,Bottom,Left,Right}` is `§ 16.3`.
