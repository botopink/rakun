# arbitrary-values

## Arbitrary values — the escape hatches

When no token names the value, build one — every builder validates its payload:

A payload that could close the rule or the `<style>` element (`{ } < > ; @ \`
in a value, anything but `[A-Za-z0-9-_]` in a name, a selector without exactly
one `&`, a length without a unit) is REFUSED, never escaped: the comptime
validators (`cssValue`, `cssIdent`, `cssSelector`, `cssQuery`, `cssLength`) fail
the build, and the builders `@panic` at run time. `ArbMin`/`ArbMax` are
`@media (width >= …)` / `(width < …)`; `arbAt` adds the `@`.
