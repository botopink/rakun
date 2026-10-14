# emilia-backgrounds

What fills a box behind its content: the seven keyword families of `Bg`, the eight gradient directions and the three stops, ending in a hero panel that covers and anchors its photograph, a gradient call to action and a gradient-text heading built with `bg-clip-text`. Nothing it emits resolves a colour or a length.

- **Tailwind section it mirrors:** Backgrounds — background-attachment, background-clip, background-origin, background-position, background-repeat, background-size, background-image (the linear gradients and their colour stops) — upstream pages [background-attachment](https://tailwindcss.com/docs/background-attachment) · [background-clip](https://tailwindcss.com/docs/background-clip) · [background-origin](https://tailwindcss.com/docs/background-origin) · [background-position](https://tailwindcss.com/docs/background-position) · [background-repeat](https://tailwindcss.com/docs/background-repeat) · [background-size](https://tailwindcss.com/docs/background-size) · [background-image](https://tailwindcss.com/docs/background-image) (Tailwind CSS v4 docs; the reference is 4.3.2's compiled output).
- **Fronts it exercises:** 1.0.10-beta front 39 (backgrounds) · front 33 (palette: `.Gradient.From.*` and `.Bg.Color.*` reach one `paletteVar`) · front 54 (theme).
- **Dependencies:** `emilia` only (`{ "workspace": true }`); targets `commonJS` and `erlang`.
- **Tests:** 12 in-file `test {}` blocks in `src/main.bp`, green on both targets.

Run from this directory, with the compiler of the enclosing botopink-lang checkout:

```sh
botopink test --target commonJS
botopink test --target erlang
botopink build --target erlang --out /tmp/emilia-backgrounds
```
