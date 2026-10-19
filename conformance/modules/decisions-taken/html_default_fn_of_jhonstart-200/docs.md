# Decision 200 — `html` is the `pub default fn` of the core member `jhonstart`, carrying `bpp`'s `#[html]` (`#[bpp.html]`, 361) — `import

`html` is the default function of `rakun-bpp` (jhonstart's core): the first import binds it as the package's default, `import html, {Element, renderToString} from "rakun-bpp";`, beside named imports in one line, and no separate markup package is depended on. `html` carries std's `#[bpp.html]`, so it is the markup's unfold target, the one an application names with `"bpp": "rakun-bpp"` in its `botopink.json`. The program writes a `nav` with a hole, renders it with `renderToString` and prints `<nav><a href="/">home</a><span>hello, world</span></nav>`.

Cells of this repository that prove it: none yet. `rakun-bpp/html-dsl/html_dsl_hole` and `html_dsl_prelude` render the same DSL imported by name (`import {html} from "rakun-bpp"`): `html.bp` still marks its function `#[bpp.html]` from the `html` module and becomes the core's `pub default fn` with `05-jhonstart/26` step 0.

[draft/main.bp](draft/main.bp)
