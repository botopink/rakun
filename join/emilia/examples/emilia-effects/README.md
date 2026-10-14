# emilia-effects

The box-shadow scale as a theme reference (it used to emit the Tailwind class suffix), inset and text shadows, the opacity steps, both blend-mode families and the mask properties, ending in a photo card that layers a shadow, a blend mode and an opacity under a hover.

- **Tailwind section it mirrors:** Effects — box-shadow, text-shadow, opacity, mix-blend-mode, background-blend-mode, mask-* — upstream pages [box-shadow](https://tailwindcss.com/docs/box-shadow) · [text-shadow](https://tailwindcss.com/docs/text-shadow) · [opacity](https://tailwindcss.com/docs/opacity) · [mix-blend-mode](https://tailwindcss.com/docs/mix-blend-mode) · [background-blend-mode](https://tailwindcss.com/docs/background-blend-mode) · [mask-image](https://tailwindcss.com/docs/mask-image) (Tailwind CSS v4 docs; the reference is 4.3.2's compiled output).
- **Fronts it exercises:** 1.0.10-beta front 41 (effects) · front 54 (the `--shadow-*` theme references) · front 34 (the hover in the photo card) · 1.0.12-beta `06-emilia/34` step 2 moves the output it pins (EM-8).
- **Dependencies:** `emilia` only (`{ "workspace": true }`); targets `commonJS` and `erlang`.
- **Tests:** 12 in-file `test {}` blocks in `src/main.bp`, green on both targets.

Run from this directory, with the compiler of the enclosing botopink-lang checkout:

```sh
botopink test --target commonJS
botopink test --target erlang
botopink build --target erlang --out /tmp/emilia-effects
```
