# Decision 671 — A field's default travels with the field into every derived type and resolves where it was written (669); there is no "closed" default.

Two modules. `links.bp` declares `Link(href, rel = defaultRel())`, its default calling a function private to that module. `main.bp` derives from it: `NoHref` is `Type.omit(Link, .href)` and `RelOnly` is `Type.pick(Link, .rel)`. Both keep `rel` with its default, and the default is still `links.bp`'s code: `NoHref()` answers `rel = "noopener"` exactly as `Link(href: "/x")` does, though `main.bp` cannot see `defaultRel`. The program prints the anchor `<a href="/x" rel="noopener">`, then `noopener` twice, then `nofollow` for the default overridden.

There is no "closed" default and no refusal of a derived type whose default reaches a private name; the one limit is that a default names only what its own module sees.

Cells of this repository that prove it: none yet — rakun-bpp's element props and its decorators that rebuild types hand the default on in front 165 s11.

[draft/main.bp](draft/main.bp)

[draft/links.bp](draft/links.bp)
