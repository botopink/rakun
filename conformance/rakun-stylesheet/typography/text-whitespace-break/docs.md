# text-whitespace-break

{src/main.bp}

`Clamp` runs `1` to `6` plus `None`, and `None` is the four-declaration RESET
rather than the absence of a token.

**Whitespace, breaking, hyphens, indent, align, tab, content:**

- **`Break` and `OverflowWrap` are two sections, not one.** Upstream's `break-*`
  and `wrap-*` overlap in EFFECT and not in PROPERTY — `break-words` is an
  `overflow-wrap` although it is spelled `break-` — and merging them would lose
  `wrap-anywhere`, which has no `break-*` spelling at all.
- **`Text.Indent` never resolves a length.** It answers front 54's
  `spacing(n)`, the same function `.Pad.All.8` answers, so the two agree by
  construction.
- **`.Text.Bold` and `.Text.Italic` are rakun-stylesheet's own leaves**, not
  transcriptions of a Tailwind utility; `font-weight:bold` is what they emitted
  before `§ 9` landed and what they emit now.
