# emilia-card

One card's three style sites — the container, the heading and the body — as three `Token[]`
lists. `emilia(tokens)` answers each site's class name; `flush()` drains the per-render
stylesheet into one layered `<style>` document. The example prints both and asserts them. It
uses emilia only: putting a class name on markup is the job of whichever library renders the
markup.

- **Tailwind section it mirrors:** Core concepts — [styling with utility classes](https://tailwindcss.com/docs/styling-with-utility-classes) · [hover, focus and other states](https://tailwindcss.com/docs/hover-focus-and-other-states) · [responsive design](https://tailwindcss.com/docs/responsive-design) (Tailwind CSS v4 docs; the reference is 4.3.2's compiled output).
- **Fronts it exercises:** 1.0.12-beta `06-emilia/33` step 2 (emilia-only, decision 114) · 1.0.10-beta front 56 (the layered document, the hoisted modifier rules) · front 33 (palette) · front 34 (`Hover`, `Md`) · front 35 (`--spacing`) · front 38 (the `--text-*` pair) · front 54 (the theme layer).
- **Dependencies:** `emilia` only (`{ "workspace": true }`); targets `commonJS` and `erlang`.
- **Tests:** 4 in-file `test {}` blocks in `src/main.bp` — the three class names as literals, the
  repeat collapse (an identical token list answers the same class), the flushed document's
  utilities layer as one literal, and a second `flush()` holding no rule. Green on both targets.

| Site | Tokens | Class |
|---|---|---|
| container | `.Pad.All.__4`, `.Bg.White`, `.Color.Black` | `e_13df5d57` |
| heading | `.Text.Size.X3xl`, `.Text.Bold`, `.Color.Red.600` | `e_41222bb0` |
| body | `.Text.Size.Base`, `.Color.Gray.600`, `Token.Hover([.Color.Red.600])`, `Token.Md([.Text.Size.Lg])` | `e_bcdc3f6a` |

The class name is `e_` and the content hash in hex; the heading's has seven digits (the hex is
not zero-padded).

## Output

`botopink run --target commonJS` and `--target erlang` print the same bytes: the three class
names, one per line, then the document. The theme's `:root` block is the full default theme
(elided here as `…`); the utilities layer and the keyframes follow it:

```text
e_13df5d57
e_41222bb0
e_bcdc3f6a
<style>@layer theme, base, components, utilities;@layer theme{:root{--spacing:0.25rem;…}}@layer utilities{.e_13df5d57{padding:calc(var(--spacing) * 4);background:#ffffff;color:var(--color-black)}.e_41222bb0{font-size:var(--text-3xl);line-height:var(--text-3xl--line-height);font-weight:bold;color:var(--color-red-600)}.e_bcdc3f6a{font-size:var(--text-base);line-height:var(--text-base--line-height);color:var(--color-gray-600)}@media (hover: hover){.e_bcdc3f6a:hover{color:var(--color-red-600)}}@media (width >= 48rem){.e_bcdc3f6a{font-size:var(--text-lg);line-height:var(--text-lg--line-height)}}}@keyframes spin{…}@keyframes ping{…}@keyframes pulse{…}@keyframes bounce{…}</style>
```

The hover and the breakpoint are sibling rules hoisted out of the body's class, each under the
at-rule its variant gives it; the breakpoint's width is the theme's `--breakpoint-md`.

Run from this directory, with the compiler of the enclosing botopink-lang checkout:

```sh
botopink run --target commonJS
botopink test --target commonJS
botopink test --target erlang
```
