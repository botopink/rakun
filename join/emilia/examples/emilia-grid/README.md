# emilia-grid

How a box lays its children out in one dimension and in two: a toolbar whose title takes the remaining space and a twelve-column dashboard that reflows per breakpoint. Nothing here emits a `rem`.

- **Tailwind section it mirrors:** Flexbox & Grid — flex-direction, flex-wrap, flex, flex-basis, flex-grow, flex-shrink, order, grid-template-columns/rows, grid-column/row, grid-auto-flow, grid-auto-columns/rows, gap, justify-*, align-*, place-* — upstream pages [flex-direction](https://tailwindcss.com/docs/flex-direction) · [flex](https://tailwindcss.com/docs/flex) · [flex-basis](https://tailwindcss.com/docs/flex-basis) · [order](https://tailwindcss.com/docs/order) · [justify-content](https://tailwindcss.com/docs/justify-content) · [align-items](https://tailwindcss.com/docs/align-items) · [place-items](https://tailwindcss.com/docs/place-items) · [grid-template-columns](https://tailwindcss.com/docs/grid-template-columns) · [grid-column](https://tailwindcss.com/docs/grid-column) · [grid-auto-flow](https://tailwindcss.com/docs/grid-auto-flow) · [gap](https://tailwindcss.com/docs/gap) (Tailwind CSS v4 docs; the reference is 4.3.2's compiled output).
- **Fronts it exercises:** 1.0.10-beta front 37 (flexbox, grid and gap) · front 35 (`Gap` and `Flex.Basis` through `spacing(n)`) · front 34 (the per-breakpoint reflow).
- **Dependencies:** `emilia` only (`{ "workspace": true }`); targets `commonJS` and `erlang`.
- **Tests:** 13 in-file `test {}` blocks in `src/main.bp`, green on both targets.

Run from this directory, with the compiler of the enclosing botopink-lang checkout:

```sh
botopink test --target commonJS
botopink test --target erlang
botopink build --target erlang --out /tmp/emilia-grid
```
