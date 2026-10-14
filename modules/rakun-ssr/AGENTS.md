# rakun-ssr

> Package `rakun-ssr` of the rakun workspace — `repository/rakun/modules/rakun-ssr/` · workspace rules: [`../../AGENTS.md`](../../AGENTS.md) · cells: `../../conformance/rakun-ssr/`

The **Next.js-style orchestrator**: the one package that imports rakun, rakun-bpp, the
`rakun-stylesheet` bridge and emilia together (decision 113) — neither rakun nor rakun-bpp names
rakun-ssr, and every value that crosses between them is handed across by `Onze.run`. Pure `.bp`
client, zero compiler-core surface, reached via `from "rakun-ssr"`.

The package is one (front 165 s2); it was ten: `onze` (the core: config, project, aliases, the boot adapter), `onze-cli`
(`src/cli/`), `onze-bundler` (`src/bundler/`), `onze-assets`
(`src/assets/`), `onze-content` (`src/content/`), `onze-og` (`src/og/`), `onze-release` (`src/release/`) and
`onze-test` (`src/testing/`) — the tests of each in the same sub-folder of `test/`, the command line `rakun-ssr`,
its configuration `rakun-ssr.json`. The tenth, `onze-server` (the rakun half of the boot, `Onze.run`), stays a package of
its own beside this one (`modules/onze-server/`): rakun is erlang-only (decision 117) and this package builds for
commonJS too (the command line runs on node), so a package holding both cannot be built for node — a question for
the coordinator. The old name came from the old mocking library,
archived under the tag `mocking-lib-final` (decision 79); nothing of it is here, and its surface is std's
`testing.mocks` / `testing.asserts`.

The snapshot engine is the `snap` library (decision 391): the package, whose tests record a `.snap`, declares
it in `dependencies` (`{ "snap": { "git": "https://github.com/botopink/snap.git", "branch": "feat" } }`)
and write `import {assertAs} from "snap";`.

## Tree

> **In the rakun workspace** (front 165 s2) this package (was `onze`, with `onze-*` folded into sub-folders of `src/` and `test/`) is `modules/rakun-ssr/`, and the tree below is the one it had as a repository of its own, its member names read as those sub-folders: its former `modules/*` are siblings in rakun's `modules/`, its cells are `conformance/rakun-ssr/`, its examples `examples/rakun-ssr/`, its refusals `refusals/rakun-ssr/`; the root manifest, `scripts/` (one gate, one hook), `.github/` and `.gitignore` are rakun's — read the tree for the package's own layout, never for those.

```text
rakun-ssr/
├── AGENTS.md          ← you are here
├── README.md
├── CHANGELOG.md
├── botopink.json      ← WORKSPACE: name rakun-ssr · targets [commonJS, erlang] ·
│                        workspaces [modules/*, examples/*]. Nothing is importable from it;
│                        `botopink build/test` here is a refusal naming the members
├── modules/           ← each: botopink.json (name, entry root.bp, files [root.bp]) + src/root.bp
│   ├── rakun-ssr/          ← CORE (front 49) — `from "rakun-ssr"`: config.bp (OnzeConfig, rakun-ssr.json,
│   │                    parsePort, the ONZE_PUBLIC_ rule; a document is read through std's
│   │                    `Json` methods — `members`, `field`, `str`, `items`, `isObject`,
│   │                    `kindName` —, `isString` the one test std lacks), types.bp (AliasMap, OnzeProject,
│   │                    describeAppFiles — what an app file is, is `routing`'s
│   │                    `conventions`, decision 323), integration.bp (the rakun-bpp half of the boot — the one
│   │                    file that imports rakun-bpp and the rakun-stylesheet bridge: bootSite,
│   │                    siteRender, rakunEntries, responseOver, pageInput). config/types tests
│   │                    import only std; integration_test.bp renders through the bridge
│   ├── rakun-ssr/   ← front 49's rakun half — targets ["erlang"] (49-e): server.bp —
│   │                    `Onze.run(config)` (reads <outDir>/build-id and the manifest, writes
│   │                    the rakun.* keys, copies rakun-bpp's UI table into rakun's with one
│   │                    PageRenderer per page, registers the fingerprinted static root,
│   │                    bootWeb, the page path, `Rakun.run(App(port, basePath))`),
│   │                    requestData, responseFor. Depends on rakun, rakun-app, rakun-service,
│   │                    rakun-bpp, rakun-ssr, rakun-ssr, rakun-ssr
│   ├── rakun-ssr/     ← the `<lib>-test` member: core.bp (assertConfig, assertAppFiles,
│   │                    assertAlias, assertPublicEnv), fixtures.bp (fixtureTree); one
│   │                    group file per front, empty until its front fills it — cli.bp,
│   │                    bundler.bp (50), assets.bp, og.bp (51), release.bp (71), e2e.bp
│   │                    (the E2E runner, 53); the front that fills one adds the member
│   │                    it imports. Depends on rakun-ssr. Re-exports nothing from std
│   ├── rakun-ssr/      ← front 50 — both rows: resolve.bp, scan.bp, generate.bp
│   │                    (the check, the staged tree under <outDir>/src/), create.bp,
│   │                    info.bp, build.bp (`rakun-ssr build`: the staged server with its
│   │                    `onze_main` and rakun-ssr, erlc into server/beam/, the styleMap
│   │                    evaluated on both backends), start.bp (`rakun-ssr start`, the server's
│   │                    generated main), main.bp (dispatch; `node out/main.js <cmd>`); dev
│   │                    answers "not available yet". Depends on rakun-ssr, rakun-ssr,
│   │                    rakun-ssr, rakun-ssr
│   ├── rakun-ssr/  ← front 68: manifest.bp (both rows — the one parser the server
│   │                    reads), scan.bp, graph.bp (an edge per `from "<alias>…"`, per
│   │                    `mod` line, per item naming an app module by its path inside the
│   │                    braces — `lib.db.Post`, decision 206 — and per shorthand sibling),
│   │                    refusal.bp (+ the styleMap probe and
│   │                    `styleParity`), chunk.bp (a page's files and pattern read through
│   │                    `routing`'s `conventions.classify` / `patternOf`), entry.bp (starters through rakun-bpp's
│   │                    `registerStarter`, the payload `s` check; components imported by
│   │                    their path inside the braces),
│   │                    script.bp, rebuild.bp, hooks.bp (RenderHooks over the tags),
│   │                    fixture.bp (the frozen fixture app every suite reads) — depends
│   │                    on rakun-ssr and rakun-bpp
│   ├── rakun-ssr/   ← fronts 69 (owns root.bp + botopink.json) · 51 · 52: style_module.bp,
│   │                    stylesheet.bp, assets.bp (the two static roots), preprocess.bp,
│   │                    head.bp (pageRenderHooks), font_metrics.bp (the committed
│   │                    table — transcribed, generator owed), font.bp (googleFont over
│   │                    a FontBuild seam, localFont, fallbackFace, fontHead), image.bp
│   │                    (Image, the allowlist), image_handler.bp (the encoder port, the
│   │                    /_onze/image outcome) — depends on rakun-ssr and rakun-bpp
│   ├── rakun-ssr/       ← front 70 — both rows: card_style.bp (the closed subset —
│   │                    `style` is taken by rakun-bpp's element), metrics.bp (front 52's
│   │                    sidecars), layout.bp, svg.bp, raster.bp (the port; NIF
│   │                    declared, never shipped), response.bp — depends on rakun-bpp (it
│   │                    parses the sidecar text itself, so no rakun-ssr edge)
│   ├── rakun-ssr/  ← front 121 — both rows (see its AGENTS.md): element.bp
│   │                    (the `markdown` library's tree as rakun-bpp's Element),
│   │                    collections.bp (loaders, typed entries, the sync and its
│   │                    store), feeds.bp (RSS 2.0); the Markdown reader is the
│   │                    `markdown` library's (decision 396); frontmatter arrives with
│   │                    step 3 — depends on markdown, rakun-bpp and validation;
│   │                    nothing imports it yet
│   └── rakun-ssr/  ← front 71: spec.bp (ReleaseSpec, the build id), otp.bp (.rel,
│                        sys.config, vm.args, bin/rakun-ssr, systools), docker.bp, package.bp
│                        (manifest completeness, the secret scan), lifecycle.bp (readiness,
│                        the shutdown order over a Lifecycle record), static_export.bp —
│                        depends on rakun-ssr and rakun-ssr
├── .gitignore         ← out/, .botopinkbuild/, .onze/ (a build's output); *.snap.new and
│                        *.snap.md.new (a snapshot mismatch's scratch file — the hook refuses
│                        one that is staged)
├── conformance/       ← the reference and its examples (decision 463): `docs.md` (rakun-ssr.json, the alias map, the four seams, the not-built table) and `modules/<example>/` cells, run by `botopink cell check conformance/` (none yet)
├── examples/          ← blog/ (53: src/lib/db.bp — the post store —, content/posts/*.md,
│                        src/components/{nav,post_card}.bp, src/app/ — layout, page, blog/
│                        layout + page, blog/[slug]/page, (marketing)/about/page —,
│                        public/, test/{db,tags,render}_test.bp; [slug] and (marketing)
│                        compile only through `rakun-ssr build`'s staged tree, and are served
│                        by `rakun-ssr start` in rakun-ssr's start_test); scaffold/ (50: the
│                        committed output of `rakun-ssr create scaffold --yes --libs ../../..`,
│                        diffed by create_test.bp); static-site (71) arrives with its front
├── scripts/git-hooks/ ← pre-commit (lib/runner-standalone.sh — one text in the five library
│                        repositories): a staged *.snap.new or conflict marker, the compiler
│                        (absent → the gate fails, never skips), `botopink test` in every
│                        workspace member — `modules/*` and `examples/*` — on every target its
│                        manifest declares (manifestTargets: the member's `targets`, else the
│                        workspace's), `botopink build` of every example on every declared
│                        target (runExamplesGate — no allow list)
└── .github/workflows/ ← test.yml (ubuntu-24.04 × {commonJS, erlang}, no macos row, every row
                         hard, OTP 28 and Node 22 on every row; one `botopink-lib-test
                         --strict` per row, the members and examples discovered from the root
                         via BOTOPINK_LIB_ROOTS; the sibling libraries and the shared
                         packages actions, routing, validation checked out as
                         dependencies; then the hook's other stages on the row's target),
                         tag.yml
```

## Rules

- A member depends on a sibling with `{ "workspace": true }` only; on another library's member by
  `path` (`{ "rakun": { "path": "../../../rakun/modules/rakun" } }`) — added by the front whose
  code needs the edge, never ahead of it. A member lists exactly the packages its sources and
  tests import: dependencies load transitively (decision 143). `std` — the one bundled
  package (decision 326) — is never listed; `routing`, `actions`, `validation` are declared
  like any library (`{ "git": "https://github.com/botopink/<pkg>.git", "branch": "feat" }`).
- A member may only **restrict** the workspace's `targets`, and only structurally (gate-d): the
  excluded target's `botopink build` must fail on a host binding (`has no #[@External.<Target>]`),
  never on a checker error, and a member that builds there runs there. Today one member
  restricts: `rakun-ssr` is `["erlang"]` — its commonJS build fails on rakun's hosts (`rkReqLive`,
  `rkBeanStore`, … `have no #[@External] for the node backend`); the rest, `rakun-ssr` and `rakun-ssr`
  included, run on both rows. Nothing on both rows imports rakun (every rakun manifest is
  `["erlang"]`, decision 117) — that is `rakun-ssr`'s.
- One module cannot hold two types of one name: an `as` alias of an imported type still binds its
  declared name (`language-gaps.md`). `rakun-ssr` constructs rakun's `App` and holds
  rakun-bpp's only as the core's `SiteRender` function value.
- The front that adds a module appends its `pub mod` line and its `files` entry in its own commit
  (`06-onze/modules.md` § Front → submodule ownership names the owner of each `root.bp`).
- An imported module's body runs before the importer's, on every backend (decision 140). The
  staged app's `onze_routes.bp` imports every decorated convention file and registers the
  undecorated ones (`loading`, `error`, `not-found`); the server's `onze_main.bp` imports
  `onze_routes` and registers every `#[page]` / `#[layout]` / `#[template]` / `#[defaultView]`
  function from the program's catalogue — `jhRegisterRoutes(@TypeInfo.all(with: page), …)`
  (decision 216); a marker registers nothing itself.
- A test writes only under `BOTOPINK_TEST_TMPDIR` (each suite's `testTmp()`); a build a test
  runs moves its `outDir` there, so nothing is written into the checkout.
- A test reads only tracked sources, never a tree another cell writes: the gate's cells run side by
  side, each member's `.botopinkbuild/` appearing and vanishing under the others. A scan over the
  members lists `modules/` and walks each member's own `src/` (`rakun-ssr`'s flush gate,
  `memberSources` in `test/stylesheet_test.bp`) — never a recursive walk of `..` or the root.
- Any code or layout change updates this file in the same commit.


## Former `onze-cli` — `src/cli/`

### rakun-ssr

> Path: `repository/rakun-ssr/modules/rakun-ssr/` · Parent: [`../../AGENTS.md`](../../AGENTS.md)
> Spec: `specs/1.0.10-beta/06-onze/50-onze-cli/README.md` in the meta repository

The `rakun-ssr` command line, commonJS only — it runs on a developer's machine before any BEAM node
exists. `compiler-cli`'s shape: `main.bp` dispatches, one module per command, pure option parsers,
no parser drops a token.

| File | What |
|---|---|
| `src/resolve.bp` | `Project`, `findRoot` (walk up to `botopink.json`), `resolveProject` (config + aliases, errors naming their file) |
| `src/scan.bp` | `RouteEntry`, `scanFiles` / `scanApp` (what an app file is: `routing`'s `conventions.classify` / `ConventionFile`, decision 323; the pattern `routing`'s `patternOf(parsePath(…))`, `""` for a segment `pathProblem` refuses — that refusal already fails the scan; the decorator argument, the three refusals — authored paths only) |
| `src/generate.bp` | `checkTree` (a file's segment is `routing`'s `conventions.classify`), `stagedPath`, `rewriteImports` (an import `from "<alias>…"` — one line or several, up to its `;` — staged as the brace form of the app module the alias names, `import {lib.format.x};`: decision 206, `from` names a package; a `from` no alias names stays), `modFiles`, `routesModule` (the undecorated conventions' registrations, and an import of every decorated convention file — by its path inside the braces — so a program importing it runs their bodies first — decision 140), `stagedManifest` (relative `path` dependencies made absolute against the project root, extra dependencies added — a directory as `{ "path": … }`, a git URL as `{ "git": …, "branch": "feat" }` (`extraDep`)), `stage` / `stageAt` — the staged tree under `<outDir>/src/` |
| `src/create.bp` | `CreateOpts`, `createDefaults` (the one defaults record), `createHelp`, `parseCreateOpts` (`--src-dir` / `--no-src-dir`, the root layout by default; `--lang` into `rakun-ssr.json`), `scaffoldLibraries(o)` (what the scaffold imports, and rakun-ssr), `scaffoldFiles(In)`, `writeScaffold`, `mkdirs` |
| `src/info.bp` | `infoText`, `dependencyVersions`, `versionAt`, `tools` |
| `src/build.bp` | `buildProject(project, bin)` — the app's sources (`sourceOfApp`: no hidden directory, and no `test/` when `src` is the project root), scan, check, the client graph's refusals, the style modules (generated into the staged tree as `styles.<file>`), the staged server package (+ `onze_main.bp` and a dependency on rakun-ssr, `memberBeside`: the member beside the project's `rakun-ssr`) compiled for erlang into `<outDir>/server/erl/` and by `erlc` into `<outDir>/server/beam/` (`compileBeam`: the files dealt to one `erlc` per CPU, an equal share each — one `erlc` compiles serially on one scheduler, ~80 s for a scaffold's ~4 000 modules; a refusal is still erlc's own text and fails the build), the staged client package (+ the generated entry, and dependencies on the `rakun-bpp` / `rakun-bpp` beside the project's `rakun-bpp`, and on `validation` as a git dependency resolved through the library roots — decision 326 — all three of which the entry imports) compiled for commonJS, the styleMap's probe run under node and under erl and compared (`BuildResult.styles`), the file-level link, the stylesheet, the build id, `static/<buildId>/`, `client-manifest.txt`, `build-id`; an absolute `outDir` is honoured; `srcDirOf`, `workspaceMembers` (a `{ "workspace": true }` dependency becomes a path in the staged manifest) |
| `src/start.bp` | `serverMainSource(config)` (the staged server's `main`: the resolved config as a literal, `PORT` over its port, the decorated conventions registered with rakun-bpp's `jhRegisterRoutes(@TypeInfo.all(with: page), …)` — decision 216 —, `Onze.run`), `startPort` (`-p`, then `PORT`, then `rakun-ssr.json`), `serverCommand` (`erl -noshell -pa <outDir>/server/beam -eval '<package>@onze_main':main()` from the project root, output to `<outDir>/server.log`), `builtOutput` (no build → an error naming the directory), `spawnServer` (the background half a test drives), `startProject` (`rakun-ssr start`, foreground) |
| `src/main.bp` | `run(cwd, args, version) -> Outcome`, `main()` — `node out/main.js <command> …` after `botopink build` |

`dev` answers "not available yet": it is `start` plus reloading changed modules into the running
node, which is not written. `start` compiles nothing and needs `erl` on `PATH`; `build` runs the
compiler through `BOTOPINK_BIN` (or `botopink` on `PATH`) and needs `erlc`, and `node` / `erl`
for the styleMap probe when the client graph calls `emilia(…)`. Route-level splitting is not done:
the generated entry imports every client component, so every island is in `shared`; no prerender
(rakun front 60).

Tests (`test/`, commonJS): `scan_test` (scan + resolve), `generate_test` (the check, the staged
tree, and a round trip that runs `botopink check` over it — the binary is found by walking up to
`repository/botopink-lang/zig-out/bin/botopink`), `create_test` (flags, help, the refusal, the
scaffold passing `botopink check`, `examples/scaffold` equal to a fresh `create`, `info`, the
dispatch, both layouts checking), `build_test` (the committed scaffold built twice
to the same id into the run's scratch directory, a refusal failing a build before anything
compiles, the contract-4 fixture's class out of the styleMap probe, a CSS module's accessors
compiling), `start_test` (the port's precedence, the refusal of an unbuilt project, `rakun-ssr build`
then the server over a real socket — the scaffold's `/`, the blog's `/blog/hello-world` and
`/about` — on a port the OS hands out (`freePort`: the gate runs the commonJS and erlang cells
side by side, so no port is written into the suite)). Every file a test writes is under `BOTOPINK_TEST_TMPDIR`.


## Former `onze-content` — `src/content/`

### rakun-ssr

> Path: `repository/rakun-ssr/modules/rakun-ssr/` · Parent: [`../../AGENTS.md`](../../AGENTS.md)
> Spec: `specs/1.0.12-beta/08-bpp/121-bpp-content/README.md` in the meta repository

The `markdown` library's tree (CommonMark 0.31.2 and the GitHub-flavoured extensions, read by the
library of decision 396) mapped to rakun-bpp's `Element`; content collections and an RSS feed. Steps 1–2,
4–5 of front 121; frontmatter (`frontmatter.bp`, step 3 — waits on `yaml`, front 142 step 2) arrives
later, and until then a `.md` entry under `glob` is a sync problem naming the step. Depends on `markdown`
(the reader and the `MdNode` tree, `{ "git": "https://github.com/botopink/markdown.git", "branch": "feat" }`;
rakun-ssr is its one consumer, the maintainer's exception to 115), rakun-bpp (`Element`, `el`, `voidEl`,
`fragment`, `text`, `raw`), std and the library `validation` (a `#[validated]` type's `parse`, `Violation`;
declared in `dependencies` as `"validation": { "git": "https://github.com/botopink/validation.git",
"branch": "feat" }` since front 138 moved it out of the compiler); nothing in rakun-ssr imports it yet.

| File | What |
|---|---|
| `src/element.bp` | `toElement(doc: MdDoc) -> Element` — the `markdown` library's tree as rakun-bpp's `Element` (raw HTML through `raw(…)`; a table cell's alignment as `style="text-align:…"`; a task item an `<input type="checkbox">`; the footnotes a `<section class="footnotes">` last). The parser, `toHtml`, `headings`, `slug` and the options are the library's |
| `src/collections.bp` | Content collections. `RawEntry(id, data: Json, body, filePath)`; `Loader = fn() -> @Task<@Result<Array<RawEntry>, string>>` — `glob(base, pattern)` (one `.json` object per file, id = the path under `base` without its extension, each segment slugged by the library's `slug`, a `slug` member overrides; a `.md` file is refused until step 3), `file(path)` (an array of objects, each with a unique non-empty `id`, taken out of the data), or the application's own function. `Collection<T>(name, loader, parse: fn(data: Json) -> @Result<T, ValidationReport>, references)` from `defineCollection(name, loader, { d -> T.parse(d) })` (the type is the only schema — validation's decisions 306, 327; 121 step 10 takes the type itself), `.reference(field, collection)` (the `// LANGUAGE GAP` form of `#[reference]`), `.erased() -> AnyCollection` (the parse kept as `check`). Readers: `getCollection`, `getCollectionWhere`, `getEntry` (`?Entry<T>`), `render(entry) -> Rendered(content: Element, headings)`; a read that meets an unreadable collection or an entry that does not decode panics naming it. The sync: `syncProblems(collections)` (every violation as `<file>: <path>: <message>`, a repeated id, a collection defined twice, a reference to a missing entry or an unsynced collection, a loader's own error), `writeStore(collections, outDir)` (refuses with every problem, else writes `<outDir>/content/<name>.json` — the data as the file wrote it); `useStore(outDir)` / `useFiles()` choose what `getCollection` reads (the process variable `ONZE_CONTENT_STORE`), `storeFile(outDir, name)` |
| `src/feeds.bp` | `RssFeed(title, description, site, items)`, `RssItem(title, link, description: ?string, pubDate: ?i64)`, `rssFeed(feed)` — RSS 2.0, every text node through std's `escape.html`, a link rooted at `/` made absolute against `site` (also the item's `guid`), a date as RFC 822 in GMT (`rfc822(epochMillis)`) |

Tests (`test/`, both rows): `element_test.bp` — the default options, `toElement` rendered with
rakun-bpp's `renderNode`; `collections_test.bp` — the loaders, the readers, the sync's problems,
references and the store, over content trees each test writes under `BOTOPINK_TEST_TMPDIR`
(`#[validated]` records of the test's own); `feeds_test.bp` — the whole document, escaping, the RFC 822
date. The CommonMark / GFM fixtures, the budget and the tree tests moved with the reader to the
`markdown` library (front 142 step 3).
