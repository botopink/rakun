# transform-raw

{src/main.bp}

#### Arbitrary values — `rawRotate`, `rawTranslate`

`rotate-[17deg]` is in the reference (`§ 16.4`'s HTML example); the translate
hatch is **provisional** — `§ 16` prints no arbitrary translate row — and exists
because a translate the five steps do not name has no other spelling. It writes
both axes and reads neither variable.

Both are top-level `Token` variants for the reason every escape hatch in rakun-stylesheet
is: a payload leaf nested inside a section cannot be constructed. The wrappers
exist because a leading-dot path followed by a payload call does not carry the
typed-array context, so `[.TransformRotateRaw("17deg")]` does not parse.
