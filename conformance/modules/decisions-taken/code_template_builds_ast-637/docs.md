# Decision 637 — Neither option: `code.bp` is built first, inside B-149, and a template answers the code it builds through `code` — the caller's holes are `syntax` values it splices, so no `Hole(index)` node exists.

The example is a markup template that answers the code it builds through std's `code` template.
`badge` is called `badge @`${user.name}``: the caller's one hole, `user.name`, reaches the body as
a `syntax` value — `compiler.holes(t)` answers the holes in order, opaque, and `h[0]` is that
expression. The body never reads its value. It writes the element it answers with
`code @`Element(tag: ${tag}, …, children: [text(${h[0]})], …)``, and `code`'s two holes are spliced
two ways: `tag` is a build value (`"span"`, chosen at build from the text's length), spliced as its
literal; `h[0]` is a `syntax` value, spliced as written, so `user.name` is typed and resolved where
`main` wrote it.

No node stands for "the caller's i-th hole": the caller's code reaches `code`'s holes as the
expression itself. `main` renders the badge for a `User` and prints `<span class="badge">ana</span>`.

Proving cells: none in this repository yet; `code.bp` and `compiler.holes` land with
`machine-2/144` B-149 (P1b, P2), and rakun-bpp's `html` is rewritten over them in front 165 s11.

[draft/main.bp](draft/main.bp)
