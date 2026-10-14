# emilia-cascade

One card whose styles reach outside its own class: a hover that is a sibling rule, a breakpoint that is a hoisted `@media` read from `--breakpoint-md`, a reset supplied through `Options` into the `base` layer, and the layered document a project's own CSS can deliberately beat.

- **Tailwind section it mirrors:** Core concepts — styling with utility classes, hover and other states, responsive design; Base styles — Preflight (supplied through `Options`); Functions and directives — `@layer` — upstream pages [styling-with-utility-classes](https://tailwindcss.com/docs/styling-with-utility-classes) · [hover-focus-and-other-states](https://tailwindcss.com/docs/hover-focus-and-other-states) · [responsive-design](https://tailwindcss.com/docs/responsive-design) · [preflight](https://tailwindcss.com/docs/preflight) · [functions-and-directives](https://tailwindcss.com/docs/functions-and-directives) (Tailwind CSS v4 docs; the reference is 4.3.2's compiled output).
- **Fronts it exercises:** 1.0.10-beta front 56 (cascade and output) · front 34 (the hoisted `Hover` / `Md` variants) · front 35 (`--spacing`) · front 54 (the theme layer).
- **Dependencies:** `emilia` only (`{ "workspace": true }`); targets `commonJS` and `erlang`.
- **Tests:** 11 in-file `test {}` blocks in `src/main.bp`, green on both targets.

Run from this directory, with the compiler of the enclosing botopink-lang checkout:

```sh
botopink test --target commonJS
botopink test --target erlang
botopink build --target erlang --out /tmp/emilia-cascade
```
