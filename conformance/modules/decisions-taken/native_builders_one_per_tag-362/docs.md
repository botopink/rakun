# Decision 362 — `05-jhonstart/26` rewrites the native builders into 351's props form, in place, and the hand-written callers with them — one builder per tag, never two.

`rakun-bpp`'s native builders take one record of props each: `a` takes `AnchorProps`, `nav` and `li` theirs, the content in the props' `children` field. The program calls each the one way there is — `a(href: "/blog", className: "active", ariaCurrent: "page", dataTrack: "nav-blog", children: [text("Blog")])`, the named arguments filling the props record — and renders the list with `renderToString`. The camelCase names print in HTML's spelling (`class`, `aria-current`), the `data-*` field is a `string` and prints as `data-track`, so the line is `<nav><ul><li><a href="/blog" class="active" aria-current="page" data-track="nav-blog">Blog</a></li><li><a href="/about">About</a></li></ul></nav>`. `el("x-badge", …)` stays the escape hatch for a tag with no builder.

The old `(children, attrs:)` form is not a second builder beside this one; a misspelt name (`hreff:`), `onClick` and any kebab-case name other than `data-*` are refused at the name, and a pair spread on an element is refused.

Cells of this repository that prove it: none yet. `rakun-bpp/components/render_nested` and the html-DSL cells still call the `(children, attrs:)` builders; the props form comes with `05-jhonstart/26` step 13 and 118 step 1, after `01-checker` s28.

[draft/main.bp](draft/main.bp)
