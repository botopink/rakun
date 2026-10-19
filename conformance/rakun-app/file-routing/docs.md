# File-convention routing

> Package: [`rakun-app`](../docs.md) · index: [`../../docs.md`](../../docs.md)

`#[restController]` routes by decorator and is untouched. `file_router.bp` (the
`rakun-app` member — add `"rakun-app": { "workspace": true }` or its path) is
the other model — a URL that comes from where a file sits:

```text
import {layout, page, PageContext, LayoutProps, pageParams, rkAppLayout, rkAppPage} from "rakun-app";

#[layout("")]
pub fn rootLayout(props: LayoutProps<Element>) -> Element { … }

#[page("blog/[slug]")]
pub fn blogPostPage(route: PageContext) -> Task<Element> {
    return post(pageParams(route).get("slug"));
}
```

The argument is the APP-RELATIVE DIRECTORY of the file, not its URL: `@Decl`
carries no source location, so a decorator cannot learn which file it was
written in, and the CLI (front 50) checks the argument against the real tree
under `rakun.appDir`. `pageParams(route)` reads the page's parameters against
the pattern its segment registered: `get(name)` for a `[name]` segment,
`list(name)` (`string[]`) for a catch-all; a name the pattern does not bind
halts, naming the pattern.

The registered table crosses the boundary as `kind|pattern|slot|verb` lines in
registration order — `L` layout, `T` template, `P` page, `D` default, `R` route
handler, `S` loading, `E` error, `N` not-found. `parseTable`, `matchPath` and
`layoutChain` read it, one implementation compiled to both targets; the host
halves (`file_router.mjs`, `sidecars/rakun_file_router.erl`) hold only the
lines and the render functions and know nothing about the format. Read a bound
parameter with `paramOf(match, name)`.

`scanAppDir(root, appDir)` is the other half: it walks the real tree, skips
`_`-prefixed folders, discovers a project-root `middleware.bp`, and refuses a
segment that holds both `page.bp` and `route.bp`, two root layouts meeting at
one URL, a registered segment with no directory and a directory that registered
nothing. `appDirOf()` reads `rakun.appDir` (front 05) and defaults to `app`, so
moving between `app/` and `src/app/` is one config line.
