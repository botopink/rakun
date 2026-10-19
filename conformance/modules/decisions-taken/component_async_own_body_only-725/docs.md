# Decision 725 — A component is never asynchronous because of its children: 375's mark counts the node's own body only.

Three rakun-bpp components, one asynchronous. `PostBody` writes `await loadPost(slug)` in its own body: it is marked, and answers a task of its tree. `PostPage` uses the synchronous hook `state` and composes `PostBody` — composing only puts the child's lambda in the tree, so `PostPage` is not marked and answers its tree directly. `Shell` calls `loadPost` without writing `await`: a call of a botopink function answering a task marks nothing, and `Shell` composes `PostPage`. The root is always asynchronous: `renderToString` walks the tree and awaits only the marked lambda, finding out while descending that the `PostBody` subtree waits. The program prints `<section><section><article><h1>hello</h1></article><p>views 1</p></section></section>`.

Cells of this repository that prove it: none yet. `rakun-bpp/server-components/server_component_sequential` awaits in a server component's own body; the composition rule arrives with front 150 s23 and 144 B-17.

[draft/main.bp](draft/main.bp)
