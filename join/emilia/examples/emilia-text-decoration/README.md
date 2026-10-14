# emilia-text-decoration

The decoration family in full (line, style, thickness, offset and the palette on the colour), lists, whitespace, word-breaking, hyphens, indent, vertical-align and `content`, ending in a footnote-bearing paragraph whose links are wavy-underlined.

- **Tailwind section it mirrors:** Typography (text half) — text-decoration-line, -color, -style, -thickness, text-underline-offset, list-style-type, white-space, word-break, hyphens, text-indent, vertical-align, content — upstream pages [text-decoration-line](https://tailwindcss.com/docs/text-decoration-line) · [text-decoration-color](https://tailwindcss.com/docs/text-decoration-color) · [text-decoration-style](https://tailwindcss.com/docs/text-decoration-style) · [text-decoration-thickness](https://tailwindcss.com/docs/text-decoration-thickness) · [text-underline-offset](https://tailwindcss.com/docs/text-underline-offset) · [list-style-type](https://tailwindcss.com/docs/list-style-type) · [white-space](https://tailwindcss.com/docs/white-space) · [word-break](https://tailwindcss.com/docs/word-break) · [hyphens](https://tailwindcss.com/docs/hyphens) · [text-indent](https://tailwindcss.com/docs/text-indent) · [vertical-align](https://tailwindcss.com/docs/vertical-align) · [content](https://tailwindcss.com/docs/content) (Tailwind CSS v4 docs; the reference is 4.3.2's compiled output).
- **Fronts it exercises:** 1.0.10-beta front 38 (typography) · front 33 (palette on the decoration colour) · front 54 (`spacing(n)` on the indent).
- **Dependencies:** `emilia` only (`{ "workspace": true }`); targets `commonJS` and `erlang`.
- **Tests:** 11 in-file `test {}` blocks in `src/main.bp`, green on both targets.

Run from this directory, with the compiler of the enclosing botopink-lang checkout:

```sh
botopink test --target commonJS
botopink test --target erlang
botopink build --target erlang --out /tmp/emilia-text-decoration
```
