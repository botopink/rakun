# emilia-transforms

`rotate`, `scale` and `translate` as three independent v4 properties that compose, the negative rotations, the two decimal conventions, the perspective family as `--perspective-*` references, and a card that lifts and a chevron that flips with a transition behind them.

- **Tailwind section it mirrors:** Transforms — rotate, scale, skew, translate, transform-origin, perspective, perspective-origin, backface-visibility, transform-style, zoom — upstream pages [rotate](https://tailwindcss.com/docs/rotate) · [scale](https://tailwindcss.com/docs/scale) · [skew](https://tailwindcss.com/docs/skew) · [translate](https://tailwindcss.com/docs/translate) · [transform-origin](https://tailwindcss.com/docs/transform-origin) · [perspective](https://tailwindcss.com/docs/perspective) · [backface-visibility](https://tailwindcss.com/docs/backface-visibility) · [zoom](https://tailwindcss.com/docs/zoom) (Tailwind CSS v4 docs; the reference is 4.3.2's compiled output).
- **Fronts it exercises:** 1.0.10-beta front 45 (transforms) · front 44 (the transition behind the card and the chevron) · front 34 (`Hover`, `GroupOpen`) · 1.0.12-beta `06-emilia/34` step 2 moves the output it pins (EM-8).
- **Dependencies:** `emilia` only (`{ "workspace": true }`); targets `commonJS` and `erlang`.
- **Tests:** 18 in-file `test {}` blocks in `src/main.bp`, green on both targets.

Run from this directory, with the compiler of the enclosing botopink-lang checkout:

```sh
botopink test --target commonJS
botopink test --target erlang
botopink build --target erlang --out /tmp/emilia-transforms
```
