# transition-entries

#### `transitionEntries()` — upstream's three `--ease-*` values

`defaultTheme()` carries the four `--animate-*` entries and **no `--ease-*`**,
so a project composes them:

| Name | Value |
| --- | --- |
| `--ease-in` | `cubic-bezier(0.4, 0, 1, 1)` |
| `--ease-out` | `cubic-bezier(0, 0, 0.2, 1)` |
| `--ease-in-out` | `cubic-bezier(0.4, 0, 0.2, 1)` |

`§ 15.4` prints the three *names* and no value; the cubic-beziers are
upstream v4's `theme.css` (4.3.2), byte for byte. The namespace is front 54's
`Ns.Ease`, so `extendTheme` accepts them and `clearNamespace(th, Ns.Ease)` drops
exactly these three; every rule references the variable and never its value.
