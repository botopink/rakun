# bg-keywords

{src/main.bp}

### Bg — the rest of the background, `§ 10.1`–`§ 10.8`

Seven keyword sub-sections sit beside `Bg.Color`. Each is one declaration, and
none of them resolves a length or reads the theme.

Three names are worth reading twice:

- **`Pos`, not `Position`.** `.Bg.Pos.Center` sets `background-position` and
  `.Layout.Position.Fixed` sets `position`; Tailwind spells both with the same
  English word and they are unrelated properties. The short head keeps the path
  four segments and keeps the two apart at a glance.
- **`Repeat.None`, not `Repeat.NoRepeat`.** The CSS value keeps its `no-`
  prefix; the token does not repeat the word its own section already says.
- **`Clip.Text` is the one clip value that is not a `*-box`.** The suffix is
  written per arm rather than derived from the leaf name, because a derived
  rule would emit `text-box` — a different value that also exists.

`.Bg.Size.*` and the top-level `Size` section are two different things:
`background-size` and the element's own `width`/`height` ladder. The same
shape as `.Bg.Color` beside the top-level `Color`.

Nothing else in `§ 10.4` is a token: `bg-[url(…)]`, `bg-size-[…]` and
`bg-position-[…]` are arbitrary values and belong to the escape-hatch front.
