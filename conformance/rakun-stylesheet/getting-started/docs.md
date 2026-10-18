# Getting started

> Package: [`rakun-stylesheet`](../docs.md) · index: [`../../docs.md`](../../docs.md)

## Install

`rakun-stylesheet` is a package of the rakun workspace: `from "rakun-stylesheet"`
resolves to the member `modules/rakun-stylesheet/` — whose `files` (`root.bp`,
`tokens.bp`, `emilia.bp`, …) is exactly what a consumer sees — and never to the
workspace, which ships nothing. `dependencies` is the object form only
(decision 76); the string array is a located error in every tool:

```jsonc
// botopink.json
{
  "dependencies": {
    "rakun-bpp": { "git": "https://github.com/botopink/rakun.git", "branch": "feat" },
    "rakun-stylesheet": { "git": "https://github.com/botopink/rakun.git", "branch": "feat" }
  }
}
```

A member of the rakun workspace writes `{ "rakun-stylesheet": { "workspace":
true } }` instead — that is what [`examples/rakun-stylesheet/emilia-card/`](../../../examples/rakun-stylesheet/emilia-card/)
does — and a project elsewhere in the ecosystem `{ "path": "…/modules/rakun-stylesheet" }`.

Bare `import { emilia.emilia, flush, Token } from "rakun-stylesheet"` resolves at v0;
the `import emilia from "rakun-stylesheet"` package-handle form is a recorded
follow-up (binds the handle but doesn't currently lower the bare
`emilia(…)` call).

## Quickstart

{quickstart/src/main.bp}

## Putting the class on an element

{class-on-element/src/main.bp}

The class is a pure function of the token list, in order, and of the theme; a
token list whose CSS is not ASCII is refused rather than hashed differently on
the two targets.

## Your own utilities and variants

A bundle is a function; `@apply` is `append`; a custom variant is a function
over the inner list; a class whose NAME is part of your API is `named`:

{own-utilities/src/main.bp}

`named` refuses a name starting with `e_`, a name outside `[A-Za-z0-9-_]`, and a
second registration of the same name with different tokens. A utility on the
same element beats it, because `components` is layered before `utilities`.
