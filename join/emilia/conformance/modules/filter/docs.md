# filter

### Filter and BackdropFilter — `§ 13`

`Filter` is `§ 13.1` on `filter`; `BackdropFilter` is `§ 13.2` on
`backdrop-filter` (not `Backdrop`, which is the `::backdrop` modifier).

| Section | Sub-sections | Emits |
| --- | --- | --- |
| `Filter` | `Blur`, `Brightness`, `Contrast`, `DropShadow`, `Grayscale`, `HueRotate`, `Invert`, `Saturate`, `Sepia` | `--tw-<family>:<fn>;filter:<chain>` |
| `BackdropFilter` | the same without `DropShadow`, plus `Opacity` (`§ 12.3`'s fifteen steps) | `--tw-backdrop-<family>:<fn>;backdrop-filter:<chain>` |

**Filters compose.** Every leaf writes its own family's custom property and one
reader, `var(--tw-blur, ) var(--tw-brightness, ) … var(--tw-drop-shadow, )`, so
`[.Filter.Blur.Sm, .Filter.Grayscale.__100]` keeps both — the empty fallbacks make
an unset family contribute nothing. `Blur.None` is `filter:none` (it replaces the
whole chain); `DropShadow.None` empties its own family (`--tw-drop-shadow: `),
as upstream does — the reference's `drop-shadow(none)` is not valid CSS.

The values are the reference's own (`brightness(.5)`, `grayscale(100%)`,
`hue-rotate(90deg)`); the blur lengths and the drop shadows are theme references
(`blur(var(--blur-md))`, `drop-shadow(var(--drop-shadow-md))`) whose values are
`filterEntries()` — compose them with `extendTheme(defaultTheme(), filterEntries())`.
Arbitrary values: `rawFilter("…")` and `rawBackdropFilter("…")`
(`Token.FilterRaw` / `Token.BackdropRaw`).
