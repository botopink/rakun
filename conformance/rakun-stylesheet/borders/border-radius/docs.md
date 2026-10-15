# border-radius

{src/main.bp}

#### Border radius — `§ 11.1`, `§ 21.5`

Ten leaves — `None`, `Xs`, `Sm`, `Md`, `Lg`, `Xl`, `X2xl`, `X3xl`, `X4xl`,
`Full` — on the shorthand **and on each of fourteen directional sub-sections**:
the four sides `T`/`R`/`B`/`L`, the four physical corners `Tl`/`Tr`/`Br`/`Bl`,
and the six logical ones `S`/`E`/`Ss`/`Se`/`Es`/`Ee`. A **side** form emits two
corner properties and a **corner** form emits one, so `.Border.Rounded.Tl.Full`
is as much a path as `.Border.Rounded.Tl.Lg` is.

> **This changed too.** `Sm`, `Md` and `Lg` used to resolve a literal `rem`;
> they reference `var(--radius-*)` now, so overriding `--radius-lg` moves every
> rounded corner. `Full` and `None` do **not** change — upstream prints those two
> literally, and neither is a theme entry.

`examples/emilia-borders/` is the worked example: one width per side, the two
axes, the six styles, the palette with its shade, and a table-like card with a
rounded top, a square bottom and a dashed internal rule.
