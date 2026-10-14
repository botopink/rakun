# emilia-modifiers

A responsive navigation bar and a peer-driven form field styled with eight modifier families at once: breakpoints both ways, dark mode under all three strategies, interaction and form state, structural position, pseudo-elements, `group` and `peer`, direction and the important flag.

- **Tailwind section it mirrors:** Core concepts — hover, focus and other states; responsive design (both directions); dark mode (all three strategies) — upstream pages [hover-focus-and-other-states](https://tailwindcss.com/docs/hover-focus-and-other-states) · [responsive-design](https://tailwindcss.com/docs/responsive-design) · [dark-mode](https://tailwindcss.com/docs/dark-mode) (Tailwind CSS v4 docs; the reference is 4.3.2's compiled output).
- **Fronts it exercises:** 1.0.10-beta front 34 (modifiers) · front 54 (`DarkMode`, `--breakpoint-*`) · front 56 (`Variant`, the hoisted sibling rules).
- **Dependencies:** `emilia` only (`{ "workspace": true }`); targets `commonJS` and `erlang`.
- **Tests:** 16 in-file `test {}` blocks in `src/main.bp`, green on both targets.

Run from this directory, with the compiler of the enclosing botopink-lang checkout:

```sh
botopink test --target commonJS
botopink test --target erlang
botopink build --target erlang --out /tmp/emilia-modifiers
```
