# mask

#### Masks

Nine properties, nine sub-sections, every value a CSS keyword. Nothing in
`Mask` reads the theme.

**The class suffix is not the CSS value.** `mask-clip-border` sets
`border-box`; a transcription that copied the suffix across would give
`mask-clip:border`, which is the same shape of defect as `box-shadow:md`.

`mask-type` is the only member of the family that declares on the **mask**
element rather than on the masked one, which is why it and `mask-mode` are two
properties over the same two words.

`§ 12.6` prints twenty rows. Nine more leaves — `Position.{Top,Bottom,Left,
Right}`, `Repeat.{RepeatX,RepeatY,Round,Space}` and `Size.Auto` — complete the
three keyword ladders; each is confirmed against upstream v4's compiled output.
