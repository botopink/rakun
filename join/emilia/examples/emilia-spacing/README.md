# emilia-spacing

Padding, margin, size and the space between children, ending in a centred article shell whose every length lives in the theme: the same token list under a theme with twice the spacing base is the same class with the same declarations, and only `:root` moves.

- **Tailwind section it mirrors:** Spacing — padding, margin, space-x/y; Sizing — width, height, min/max-width, min/max-height — upstream pages [padding](https://tailwindcss.com/docs/padding) · [margin](https://tailwindcss.com/docs/margin) · [width](https://tailwindcss.com/docs/width) · [height](https://tailwindcss.com/docs/height) (Tailwind CSS v4 docs; the reference is 4.3.2's compiled output).
- **Fronts it exercises:** 1.0.10-beta front 35 (spacing and sizing) · front 54 (`--spacing`, `--container-*`).
- **Dependencies:** `emilia` only (`{ "workspace": true }`); targets `commonJS` and `erlang`.
- **Tests:** 12 in-file `test {}` blocks in `src/main.bp`, green on both targets.

Run from this directory, with the compiler of the enclosing botopink-lang checkout:

```sh
botopink test --target commonJS
botopink test --target erlang
botopink build --target erlang --out /tmp/emilia-spacing
```
