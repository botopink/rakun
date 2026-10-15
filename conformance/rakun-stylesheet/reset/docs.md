# The reset

> Package: [`rakun-stylesheet`](../docs.md) · index: [`../../docs.md`](../../docs.md)

Tailwind's utilities assume a reset (`§ 4`): `border` is `1px` visible only
because everything already has `border-width:0;border-style:solid`, and
`before:`/`after:` render only because `content:""` is set. rakun-stylesheet ships the
reset and never applies it on its own:

{preflight/src/main.bp}

Eleven rules in the `base` layer: box-sizing and zero-width solid borders on
everything, `html`'s line-height, margins off `body`, headings and lists,
inherited link colour and decoration, block images, inherited fonts in form
controls, and `content:""` on `::before`/`::after`. Parity with `§ 4`, not a
byte copy of upstream's `preflight.css`.
