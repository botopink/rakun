# emilia-transitions

The six preset bundles as three declarations from one token, the two ms ladders, the easings as theme references, the four built-in animations with their hoisted `@keyframes` blocks, and a submit button that transitions its colours on hover and swaps to a spinner while the form is in flight.

- **Tailwind section it mirrors:** Transitions & Animation — transition-property, transition-behavior, transition-duration, transition-timing-function, transition-delay, animation — upstream pages [transition-property](https://tailwindcss.com/docs/transition-property) · [transition-behavior](https://tailwindcss.com/docs/transition-behavior) · [transition-duration](https://tailwindcss.com/docs/transition-duration) · [transition-timing-function](https://tailwindcss.com/docs/transition-timing-function) · [transition-delay](https://tailwindcss.com/docs/transition-delay) · [animation](https://tailwindcss.com/docs/animation) (Tailwind CSS v4 docs; the reference is 4.3.2's compiled output).
- **Fronts it exercises:** 1.0.10-beta front 44 (transitions and animation) · front 54 (the `--ease-*` theme references) · front 34 (`Hover`) · 1.0.12-beta `06-emilia/34` step 2 moves the output it pins (EM-8).
- **Dependencies:** `emilia` only (`{ "workspace": true }`); targets `commonJS` and `erlang`.
- **Tests:** 14 in-file `test {}` blocks in `src/main.bp`, green on both targets.

Run from this directory, with the compiler of the enclosing botopink-lang checkout:

```sh
botopink test --target commonJS
botopink test --target erlang
botopink build --target erlang --out /tmp/emilia-transitions
```
