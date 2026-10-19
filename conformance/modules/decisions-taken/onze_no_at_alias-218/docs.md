# Decision 218 — onze's `@/` alias goes: an application writes `import {lib.db.findPost};`; staging no longer rewrites `from "@/…"`, whic

The application keeps its data in `draft/lib/db.bp`, the module `lib.db`, and its page imports `findPost` from there with `import {lib.db.findPost};`. The braces carry the path, and no `from` is written. `PostPage("hello")` renders the post's title and body, so the program prints `<article><h1>Hello, rakun</h1><p>The first post.</p></article>`.

There is no `@/` alias. `import {findPost} from "@/lib/db";` is no longer rewritten by `rakun-ssr`'s staging; it is refused like any `from` that names a module of the importing package, with `module-import-with-from` at the source string and the brace form as the fix. `rakun-ssr`'s scaffold declares no `"alias"` key.

Cells in this repository that prove it: none yet. The bundler's `AliasMap` and `resolveAlias` leave with front 150 s60 step 9.

[draft/main.bp](draft/main.bp)
[draft/lib/db.bp](draft/lib/db.bp)
