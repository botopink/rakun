# Escape hatches

> Package: [`rakun-stylesheet`](../docs.md) · index: [`../../docs.md`](../../docs.md)

## Arbitrary values — the escape hatches

When no token names the value, build one — every builder validates its payload:

{arbitrary-values/src/main.bp}

A payload that could close the rule or the `<style>` element (`{ } < > ; @ \`
in a value, anything but `[A-Za-z0-9-_]` in a name, a selector without exactly
one `&`, a length without a unit) is REFUSED, never escaped: the comptime
validators (`cssValue`, `cssIdent`, `cssSelector`, `cssQuery`, `cssLength`) fail
the build, and the builders `@panic` at run time. `ArbMin`/`ArbMax` are
`@media (width >= …)` / `(width < …)`; `arbAt` adds the `@`.

## Deviations

Where rakun-stylesheet does not render a Tailwind 4.3.2 feature as a token (decision 401);
the escape hatch is `arbSel` (see "Arbitrary values").

- **Named `has` / `not` / ARIA / data-attribute / `in` variants** have no named
  tokens; write the selector with `arbSel`:

  {deviations-arbsel/src/main.bp}

- **`@theme inline` is not supported.** Every theme reference renders
  `var(--x)`; there is no render mode that resolves the value into each site.
