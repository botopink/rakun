# The client bundle

> Package: [`rakun-ssr`](../docs.md) · index: [`../../docs.md`](../../docs.md)

`rakun-ssr build` walks the client module graph textually (the compiler exposes no module-graph API):
every `import … ;` and `mod …;` line of every `.bp` file, an unreadable import failing the scan with
`file:line`. The roots are the `#[client]` modules the route modules reach on the server side; each
root's closure is the client graph, and every node keeps the chain from the root that pulled it in.

**The build refuses**, with no flag, config key or annotation that relaxes it, a client-graph module
that imports rakun-bpp's `serverOnly` (or `request` / `cookies` / `headers`), reads a non-`ONZE_PUBLIC_`
variable, reads a variable whose name is not a literal, calls `env.vars()` / `env.write` /
`env.clear`, calls `emilia(…)` with a token list that is not a literal (or a module-level `val` of
one), calls `flush()`, or writes a non-ASCII token list (the two targets' `contentHash` would
disagree). Every refusal of a build is printed, each with its chain:

```text
refused: server-only module lib.db reached from client root components.status
  components.status > lib.format > lib.db
build failed: 1 refusal
```

**Chunks.** `shared` (every client module two or more routes reach, plus rakun-bpp's client
runtime), one `route:<pattern>` chunk per route that reaches a module of its own, and `entry` (the
generated hydration entry). Each is the `__onze_require` registry prelude plus one factory per
module, named `<base>.<contentHash>.js` and served from `/_onze/static/<buildId>/` — immutable, so
two builds of an unchanged tree give the same names and one changed byte changes exactly the
chunks containing it.

**The manifest**, `<outDir>/client-manifest.txt`, read back by the server on every render:

```text
V|1|<buildId>
E|entry|/_onze/static/<buildId>/entry.<hash>.js|<hash>|<bytes>
S|shared|/_onze/static/<buildId>/shared.<hash>.js|<hash>|<bytes>
C|route:/blog/[slug]|/_onze/static/<buildId>/r1.<hash>.js|<hash>|<bytes>
H|script:analytics|/a.js|<hash>|<bytes>
R|/blog/[slug]|route:/blog/[slug]
Y|styles|/_onze/static/<buildId>/app.<hash>.css|<hash>|<bytes>
P|ONZE_PUBLIC_API_URL|https://api.example.com
```

A field escapes `%`, `|`, line feed and carriage return (`%25`, `%7C`, `%0A`, `%0D`) and is read
back with std's `percentDecode`. A line of an unknown kind is ignored; a `V` other than `1` is an
error. One parser, both targets.

**The script-tag order**, straddling rakun-bpp's render:

| # | What | Where | Owner |
|---|---|---|---|
| 1 | every `beforeInteractive` script (`H`), blocking | `<head>` | `headScriptTags` |
| 2 | the document's markup | `<body>` | rakun-bpp's render |
| 3 | the payload script, `window.__bp0 = …` | end of `<body>` | rakun-bpp's render, never rakun-ssr |
| 4 | `shared`, `defer` | after the payload | `scriptTags` |
| 5 | the route chunk, `defer` | after `shared` | `scriptTags` |
| 6 | `entry`, `defer` | last | `scriptTags` |

`bundleRenderHooks(manifest)` wraps the two functions as rakun-bpp's `RenderHooks`; `bootSite`
installs them. `afterInteractive` and `lazyOnload` scripts are scheduled by the entry, `worker`
scripts started by it (a worker cannot declare `onLoad`).

**The entry** is generated botopink source and spells no `__`-prefixed name: it sets the validation
message source, registers `globals.fill` and `globals.signal` (with `allowedRedirects`), registers
one starter per client component with rakun-bpp's `registerStarter` (the `globals.starters` table
`hydrate()` reads; each starter decodes the island's props into the component's `#[clientProps]`
record from its source and, before committing the markup, raises on a rakun-stylesheet class the payload's
`s` key does not list — the server's stylesheet has no rule for it), raises on an island or a hole
present on one side of the document/payload only, then calls `hydrate()`, `linkMount()` and
`formMount(actionHeader)`. It imports nothing from `routing` and nothing of rakun.

**The styleMap is evaluated on both backends.** Each literal `emilia(…)` call of the client graph is
compiled into a probe module (`onze_styles`) in the client package and in the server package;
`rakun-ssr build` runs it under node and under erl — rakun-stylesheet's own `styleRule(tokens, defaultTheme())`,
the rule body hashed with std's `contentHash` — and a call whose class or body hash differs between
the two fails the build (`emilia-hash-split`, naming the token list). The classes the two agree on
are the build's `styles`.

**Dev.** A body edit relinks only the chunks containing the module; an import edit re-walks the
graph; a refusal fails dev with the build's own report; the manifest is written before the push.
