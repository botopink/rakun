# Styles and static files

> Package: [`rakun-ssr`](../docs.md) · index: [`../../docs.md`](../../docs.md)

**rakun-stylesheet's block is not rakun-ssr's.** rakun-bpp's render writes it — into the head after the shell,
into each streamed boundary's fill, and the payload's `s` — through the `rakun-stylesheet`
`RenderPlugin` that `bootSite` registers; the ordering rule is rakun-bpp front 30's and rakun-ssr
restates none of it.

**CSS Modules.** `app/blog/blog.module.css` becomes the generated `.onze/styles/app_blog_blog.bp`,
one accessor per class the file defines (a class that begins a selector), renamed
`<file>_<class>_<hash>` (six hex digits of std's `contentHash` of the file) in the selectors only.
The accessors are `pub val`s of a module of the staged app — `import {styles.app_blog_blog.container};
… container`. A class used but not defined is left as written
and reported once; `:global(…)` is not supported; a file containing `</style` is refused.

**The stylesheet.** The global CSS (`app/globals.css`), then every module's rewritten CSS, in one
file, `/_onze/static/<buildId>/app.<hash>.css`, linked in the head (never inlined — it does not
change per request). Its `Y` record goes into the client manifest. `pageRenderHooks(manifest)`
is the head fragment (the stylesheet `<link>`s, then the `beforeInteractive` scripts) and the body
tags as rakun-bpp's `RenderHooks`.

**Two static roots**, served by rakun-service front 82 (rakun-ssr serves no file), and no configuration
adds a third:

| Root | Directory | Cache |
|---|---|---|
| `/_onze/static/<buildId>/**` | `<outDir>/static/<buildId>/` | `public, max-age=31536000, immutable` |
| `/**` | `public/` | `no-cache` |

`Onze.run` registers the first with rakun-service's `registerStaticRoot`. The second is not registered
yet: rakun-service answers every request its pattern admits and a miss is a 404, so a `/**` root would
answer every page's URL (decision pending 69-b). Every other directory — `app/`, `src/`,
`content/`, `lib/`, `.onze/` — is unreachable over HTTP.

**Preprocessors.** `preprocess(command, inputPath)` runs the configured command with the input path
and takes its stdout; no command means the file as written; a missing command or a non-zero exit
fails the build naming the command, with its output attached.
