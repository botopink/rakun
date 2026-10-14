# emilia-borders

The `Border` section end to end: the widths per side and per axis, the six styles, the palette on the colour and the radius family with its physical and logical corners, ending in a table-like card with a rounded top, a square bottom and a dashed internal rule.

- **Tailwind section it mirrors:** Borders — border-width, border-style, border-color, border-radius — upstream pages [border-width](https://tailwindcss.com/docs/border-width) · [border-color](https://tailwindcss.com/docs/border-color) · [border-style](https://tailwindcss.com/docs/border-style) · [border-radius](https://tailwindcss.com/docs/border-radius) (Tailwind CSS v4 docs; the reference is 4.3.2's compiled output).
- **Fronts it exercises:** 1.0.10-beta front 40 (borders) · front 33 (palette on `border-color`) · front 54 (the `--radius-*` theme references) · front 56 (`Rule` / `Sheet` read back).
- **Dependencies:** `emilia` only (`{ "workspace": true }`); targets `commonJS` and `erlang`.
- **Tests:** 10 in-file `test {}` blocks in `src/main.bp`, green on both targets.

Run from this directory, with the compiler of the enclosing botopink-lang checkout:

```sh
botopink test --target commonJS
botopink test --target erlang
botopink build --target erlang --out /tmp/emilia-borders
```
