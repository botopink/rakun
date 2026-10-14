# emilia-layout

Where a box sits, what it clips and what it stacks over: the eleven display values, position and the inset family, overflow, z-index and the rest, ending in a media card that crops its image and a sticky header over a scrolling panel.

- **Tailwind section it mirrors:** Layout — display, position, top/right/bottom/left, overflow, visibility, z-index, isolation, float, clear, object-fit, aspect-ratio, columns, box-sizing — upstream pages [display](https://tailwindcss.com/docs/display) · [position](https://tailwindcss.com/docs/position) · [top-right-bottom-left](https://tailwindcss.com/docs/top-right-bottom-left) · [overflow](https://tailwindcss.com/docs/overflow) · [visibility](https://tailwindcss.com/docs/visibility) · [z-index](https://tailwindcss.com/docs/z-index) · [float](https://tailwindcss.com/docs/float) · [object-fit](https://tailwindcss.com/docs/object-fit) · [aspect-ratio](https://tailwindcss.com/docs/aspect-ratio) · [columns](https://tailwindcss.com/docs/columns) · [box-sizing](https://tailwindcss.com/docs/box-sizing) (Tailwind CSS v4 docs; the reference is 4.3.2's compiled output).
- **Fronts it exercises:** 1.0.10-beta front 36 (layout) · front 35 (`Inset` through `spacing(n)`) · front 54 (the `--container-*` ladder).
- **Dependencies:** `emilia` only (`{ "workspace": true }`); targets `commonJS` and `erlang`.
- **Tests:** 12 in-file `test {}` blocks in `src/main.bp`, green on both targets.

Run from this directory, with the compiler of the enclosing botopink-lang checkout:

```sh
botopink test --target commonJS
botopink test --target erlang
botopink build --target erlang --out /tmp/emilia-layout
```
