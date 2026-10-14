# emilia-theme

A theme is a module: a project defines its brand theme in one function, clears the stock colour namespace, reads a value back, and styles a card with spacing that resolves against the theme's `--spacing`.

- **Tailwind section it mirrors:** Core concepts — theme variables (`@theme`, namespaces, clearing a namespace, sharing a theme) — upstream pages [theme](https://tailwindcss.com/docs/theme) (Tailwind CSS v4 docs; the reference is 4.3.2's compiled output).
- **Fronts it exercises:** 1.0.10-beta front 54 (theme) · front 56 (the theme rendered into the `theme` cascade layer through `Options`) · front 35 (`spacing`).
- **Dependencies:** `emilia` only (`{ "workspace": true }`); targets `commonJS` and `erlang`.
- **Tests:** 10 in-file `test {}` blocks in `src/main.bp`, green on both targets.

Run from this directory, with the compiler of the enclosing botopink-lang checkout:

```sh
botopink test --target commonJS
botopink test --target erlang
botopink build --target erlang --out /tmp/emilia-theme
```
