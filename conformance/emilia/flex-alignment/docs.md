# flex-alignment

#### Alignment — nine property groups, all under `Flex`

**Alignment applies to grid as much as to flex, and it lives under `Flex`
anyway.** `align-items` and `justify-content` were spelled that way before this
front, and renaming a token that compiles today is what the milestone forbids.
A grid container writes `.Flex.Justify.Center` and gets
`justify-content:center`, which is the correct CSS for a grid; only the token's
spelling reads as though it were flex-only.

**Upstream is not internally consistent and emilia copies it rather than
smoothing it.** `justify-content`, `align-items`, `align-self` and
`align-content` take `flex-start` / `flex-end`; `justify-items`,
`justify-self` and the whole `place-*` family take `start` / `end`. One test is
dedicated to the asymmetry, asserting both spellings come out of the right
tokens.

`AlignSelf` and the flat `PlaceContent` / `PlaceItems` / `PlaceSelf`, rather
than `Self` and a nested `Place { … }`: **`Self` is a language keyword**, so a
section cannot be named it. The family is flattened the way `Break` is, and no
emitted byte differs.
