# effect-shadow-fix

#### The defect, stated plainly

`.Effect.Shadow.Md` used to emit **`box-shadow:md`**. That is the Tailwind
class suffix in the position a CSS value belongs; a browser discards the whole
declaration, so a card that asked for a shadow rendered flat. All four of
`Sm`/`Md`/`Lg`/`Xl` did it, and the only assertion that touched the family
pinned the wrong string. The four leaf **names** did not move, so nothing
that compiled before stops compiling; what they emit is the fix.
