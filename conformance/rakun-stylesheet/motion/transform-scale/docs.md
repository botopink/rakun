# transform-scale

{src/main.bp}

#### Scale — upstream v4's three variables

A step is a **percentage** written into `--tw-scale-x`, `--tw-scale-y` and
`--tw-scale-z`, then read by one `scale:var(--tw-scale-x) var(--tw-scale-y)`;
`ScaleX` / `ScaleY` write their own axis only, so the two compose:

The three variables are registered with `@property` (initial value `1`), so an
axis nobody set reads as identity. The reference file's `scale:.5` /
`scale:.5 1` is v3's shape. `.Transform.Zoom.__50` stays `zoom:0.5`, the
reference's bare number.
