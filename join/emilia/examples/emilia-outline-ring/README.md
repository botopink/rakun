# emilia-outline-ring

The three families that had no token at all: a focus ring that does not move layout, the `outline-none` trap (a transparent outline, never `outline-style:none`), a ring that composes with a shadow rather than overwriting it, and a segmented list separated by `divide-y` on its children.

- **Tailwind section it mirrors:** Borders — outline-width, outline-color, outline-style, outline-offset, box-shadow's ring utilities, divide-* — upstream pages [outline-width](https://tailwindcss.com/docs/outline-width) · [outline-color](https://tailwindcss.com/docs/outline-color) · [outline-style](https://tailwindcss.com/docs/outline-style) · [outline-offset](https://tailwindcss.com/docs/outline-offset) · box-shadow (ring) · border-width (divide) (Tailwind CSS v4 docs; the reference is 4.3.2's compiled output).
- **Fronts it exercises:** 1.0.10-beta front 40 (outlines, rings, divides) · front 35 (`siblingSelector()`, shared with `space-*`) · front 41 (the ring composes with `--tw-shadow`) · front 34 (`FocusVisible`) · 1.0.12-beta `06-emilia/34` step 2 moves the output it pins (EM-8).
- **Dependencies:** `emilia` only (`{ "workspace": true }`); targets `commonJS` and `erlang`.
- **Tests:** 13 in-file `test {}` blocks in `src/main.bp`, green on both targets.

Run from this directory, with the compiler of the enclosing botopink-lang checkout:

```sh
botopink test --target commonJS
botopink test --target erlang
botopink build --target erlang --out /tmp/emilia-outline-ring
```
