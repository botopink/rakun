# transition-raw

#### Arbitrary values — `rawTransitionProperty`, `rawAnimate`

`Token.TransitionProperty(value)` and `Token.AnimateRaw(value)` are **top-level**
variants, not `Transition.Property(…)` / `Animate.Raw(…)`, because a payload
leaf nested inside an enum section cannot be constructed by any spelling (see
§ `Color.Hex("#abc")` is declared and unconstructible). For `AnimateRaw` that is
not an inconvenience: it is the *only* way to name an animation this library
does not ship, so the nested spelling would have shut the door rather than
narrowed it. The wrappers exist because a leading-dot path followed by a payload
call does not carry the typed-array context either.

`rawAnimate` goes through `declSheet` and **not** through `animateTokenToSheet`:
a custom animation names keyframes emilia does not own, so it hoists no block.

`§ 15` prints no arbitrary-value row; both were measured against upstream v4.
`rawAnimate` is `animation:<value>`, as upstream's `animate-[…]`.
`rawTransitionProperty` writes the property **and** the timing and duration
defaults, as upstream's `transition-[…]` and every preset beside it do:
`transition-property:width;transition-timing-function:var(--ease-out);transition-duration:150ms`.
