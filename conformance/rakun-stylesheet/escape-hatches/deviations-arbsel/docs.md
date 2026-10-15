# deviations-arbsel

{src/main.bp}

## Deviations

Where rakun-stylesheet does not render a Tailwind 4.3.2 feature as a token (decision 401);
the escape hatch is `arbSel` (see "Arbitrary values").

- **Named `has` / `not` / ARIA / data-attribute / `in` variants** have no named
  tokens; write the selector with `arbSel`:

- **`@theme inline` is not supported.** Every theme reference renders
  `var(--x)`; there is no render mode that resolves the value into each site.
