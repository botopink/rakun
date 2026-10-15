# Fonts

> Package: [`rakun-ssr`](../docs.md) · index: [`../../docs.md`](../../docs.md)

`googleFont(family, opts, buildId, outDir)` fetches the Google CSS once at build time (`curl`, a
fixed modern `User-Agent`), keeps the requested subsets, downloads each `woff2` into
`<outDir>/static/<buildId>/fonts/<family>-<weight>.<hash>.woff2` and writes a `.metrics.txt`
sidecar beside it; nothing at request time touches a Google host. The `Font` value carries a class
(`onze-font-inter`), an optional CSS variable, the CSS (`@font-face` per weight × style, the
adjusted fallback, the `:root` variable, the class rule), the preload tags and a `font-family`
string. `fontHead(fonts)` is the preload tags, then one `<style>` of every distinct rule.

**The adjusted fallback** — `size-adjust` (the ratio of the average advances, each over its
`unitsPerEm`), `ascent-override`, `descent-override`, `line-gap-override` (the real face's values
over its `unitsPerEm`) — comes from the committed metrics table. A family missing from the table
with `adjustFontFallback: true` is refused. The table's rows are transcribed, not generated here;
the generator is owed.

**`localFont` without a metrics probe is a degradation, named as one**: the face is emitted with no
adjusted fallback — layout-shift mitigation is off for that family — and the build logs one line
naming the family. It does not guess metrics: a wrong `size-adjust` is worse than none.
