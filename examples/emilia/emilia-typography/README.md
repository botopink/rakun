# emilia-typography

The type scale as a theme reference with its paired line-height, the nine weights, the font sub-sections, tracking and leading, line-clamp and the wrap family, ending in an article header over a clamped excerpt.

- **Tailwind section it mirrors:** Typography (font half) — font-family, font-size, font-smoothing, font-style, font-weight, font-stretch, font-variant-numeric, letter-spacing, line-clamp, line-height, text-transform, text-overflow, text-wrap — upstream pages [font-size](https://tailwindcss.com/docs/font-size) · [font-weight](https://tailwindcss.com/docs/font-weight) · [font-smoothing](https://tailwindcss.com/docs/font-smoothing) · [font-stretch](https://tailwindcss.com/docs/font-stretch) · [font-variant-numeric](https://tailwindcss.com/docs/font-variant-numeric) · [letter-spacing](https://tailwindcss.com/docs/letter-spacing) · [line-height](https://tailwindcss.com/docs/line-height) · [line-clamp](https://tailwindcss.com/docs/line-clamp) · [text-transform](https://tailwindcss.com/docs/text-transform) · [text-overflow](https://tailwindcss.com/docs/text-overflow) · [text-wrap](https://tailwindcss.com/docs/text-wrap) (Tailwind CSS v4 docs; the reference is 4.3.2's compiled output).
- **Fronts it exercises:** 1.0.10-beta front 38 (typography) · front 54 (`--text-*`, `--font-*`, `--tracking-*`, `--leading-*`).
- **Dependencies:** `emilia` only (`{ "workspace": true }`); targets `commonJS` and `erlang`.
- **Tests:** 11 in-file `test {}` blocks in `src/main.bp`, green on both targets.

Run from this directory, with the compiler of the enclosing botopink-lang checkout:

```sh
botopink test --target commonJS
botopink test --target erlang
botopink build --target erlang --out /tmp/emilia-typography
```
