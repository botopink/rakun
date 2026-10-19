# Decision 289 — A module's default function may be anonymous:

A route module and a recursive component, each a module whose default is a function. `page.bp` is what a `.bpp` route file unfolds to: its header imports `rakun-bpp`'s `page` decorator and writes `#[page("blog/[slug]")]` on `pub default fn () -> Component<Element>` — a default with no name of its own, so the decorator named `page` and the module named `page` never bind one name twice; the decorator reads the declaration's name as the file's, `page`. `tree.bp` declares `fn Tree(depth: i32)`, which calls itself by name, and makes it the module's default with `pub default Tree;`. `main.bp` imports both by their paths: `import {page};` binds the anonymous default as `page`, `import {tree as Tree};` binds the other under an alias. The program renders the page and then the tree three levels deep, printing `<article><h1>post</h1></article>` and the nested lists.

A route file whose name is no identifier (`not-found.bpp`) unfolds the same way; its importer names it with an alias.

Cells of this repository that prove it: none yet. `examples/rakun-ssr/blog` still names its page functions (`pub fn post(…)`); the anonymous route defaults come with 116 step 2 and `04-rakun/22` step 7.

[draft/main.bp](draft/main.bp)

[draft/page.bp](draft/page.bp)

[draft/tree.bp](draft/tree.bp)
