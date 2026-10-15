# interact

{src/main.bp}

### Interact — `§ 17`

Cursor, form controls, pointer events, resize, selection, `will-change`,
touch, scrolling and snapping — one section, 161 leaves.

- `cursor-default` is `.Interact.Cursor.Standard`; `accent-auto` is
  `.Interact.AccentAuto`.
- Three class names lie about their value: `.Interact.Resize.Y` is
  `resize:vertical`, `.Resize.X` is `horizontal`, `.WillChange.Scroll` is
  `scroll-position`.
- `.Interact.Scroll.{M,Mx,My,Mt,Mr,Mb,Ml,P,Px,Py,Pt,Pr,Pb,Pl}.__N` (0, 1, 2, 4,
  8) are `spacing(n)`; the axis forms are two declarations, left before right.
- `.Interact.Snap.Type.X` is `scroll-snap-type:x var(--tw-scroll-snap-strictness,
  proximity)`: alone it snaps by proximity, and `.Snap.Strictness.Mandatory` in
  the same list makes it mandatory.
- Colours are top-level variants carrying a palette reference, never a hex:
  `accent(v)`, `caret(v)`, `scrollbarColor(thumb, track)` with
  `paletteVar(family, shade)`.
