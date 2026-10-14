# onze

> Package `onze` of the rakun workspace — `repository/rakun/modules/onze/` · workspace rules: [`../../AGENTS.md`](../../AGENTS.md) · cells: `../../conformance/onze/`

The **Next.js-style orchestrator**: the one package that imports rakun, jhonstart, the
`jhonstart-emilia` bridge and emilia together (decision 113) — neither rakun nor jhonstart names
onze, and every value that crosses between them is handed across by `Onze.run`. Pure `.bp`
client, zero compiler-core surface, reached via `from "onze"`.

The workspace and its nine members exist (front 95, `onze-server` — decision pending 49-e — and
`onze-content`, front 121):
rakun is erlang-only (decision 117), so the rakun half of the boot lives in the erlang member
`onze-server` and the core stays on both rows. The name came from the old mocking library, archived
under the tag `mocking-lib-final` (decision 79); nothing of it is here, and its surface is std's
`testing.mocks` / `testing.asserts`.

The snapshot engine is the `snap` library (decision 391): the members whose tests record a `.snap`
(`onze`, `onze-assets`, `onze-bundler`, `onze-cli`, `onze-og`, `onze-release`, `onze-test`) declare
it in `dependencies` (`{ "snap": { "git": "https://github.com/botopink/snap.git", "branch": "feat" } }`)
and write `import {assertAs} from "snap";`.

## Tree

> **In the rakun workspace** (front 165 s1) this package is `modules/onze/`, and the tree below is the one it had as a repository of its own: its former `modules/*` are siblings in rakun's `modules/`, its cells are `conformance/onze/`, its examples `examples/onze/`, its refusals `refusals/onze/`; the root manifest, `scripts/` (one gate, one hook), `.github/` and `.gitignore` are rakun's — read the tree for the package's own layout, never for those.

```text
onze/
├── AGENTS.md          ← you are here
├── README.md
├── CHANGELOG.md
├── botopink.json      ← WORKSPACE: name onze · targets [commonJS, erlang] ·
│                        workspaces [modules/*, examples/*]. Nothing is importable from it;
│                        `botopink build/test` here is a refusal naming the members
├── modules/           ← each: botopink.json (name, entry root.bp, files [root.bp]) + src/root.bp
│   ├── onze/          ← CORE (front 49) — `from "onze"`: config.bp (OnzeConfig, onze.json,
│   │                    parsePort, the ONZE_PUBLIC_ rule; a document is read through std's
│   │                    `Json` methods — `members`, `field`, `str`, `items`, `isObject`,
│   │                    `kindName` —, `isString` the one test std lacks), types.bp (AliasMap, OnzeProject,
│   │                    describeAppFiles — what an app file is, is `routing`'s
│   │                    `conventions`, decision 323), integration.bp (the jhonstart half of the boot — the one
│   │                    file that imports jhonstart and the jhonstart-emilia bridge: bootSite,
│   │                    siteRender, rakunEntries, responseOver, pageInput). config/types tests
│   │                    import only std; integration_test.bp renders through the bridge
│   ├── onze-server/   ← front 49's rakun half — targets ["erlang"] (49-e): server.bp —
│   │                    `Onze.run(config)` (reads <outDir>/build-id and the manifest, writes
│   │                    the rakun.* keys, copies jhonstart's UI table into rakun's with one
│   │                    PageRenderer per page, registers the fingerprinted static root,
│   │                    bootWeb, the page path, `Rakun.run(App(port, basePath))`),
│   │                    requestData, responseFor. Depends on rakun, rakun-app, rakun-web,
│   │                    jhonstart, onze, onze-bundler, onze-assets
│   ├── onze-test/     ← the `<lib>-test` member: core.bp (assertConfig, assertAppFiles,
│   │                    assertAlias, assertPublicEnv), fixtures.bp (fixtureTree); one
│   │                    group file per front, empty until its front fills it — cli.bp,
│   │                    bundler.bp (50), assets.bp, og.bp (51), release.bp (71), e2e.bp
│   │                    (the E2E runner, 53); the front that fills one adds the member
│   │                    it imports. Depends on onze. Re-exports nothing from std
│   ├── onze-cli/      ← front 50 — both rows: resolve.bp, scan.bp, generate.bp
│   │                    (the check, the staged tree under <outDir>/src/), create.bp,
│   │                    info.bp, build.bp (`onze build`: the staged server with its
│   │                    `onze_main` and onze-server, erlc into server/beam/, the styleMap
│   │                    evaluated on both backends), start.bp (`onze start`, the server's
│   │                    generated main), main.bp (dispatch; `node out/main.js <cmd>`); dev
│   │                    answers "not available yet". Depends on onze, onze-bundler,
│   │                    onze-assets, onze-release
│   ├── onze-bundler/  ← front 68: manifest.bp (both rows — the one parser the server
│   │                    reads), scan.bp, graph.bp (an edge per `from "<alias>…"`, per
│   │                    `mod` line, per item naming an app module by its path inside the
│   │                    braces — `lib.db.Post`, decision 206 — and per shorthand sibling),
│   │                    refusal.bp (+ the styleMap probe and
│   │                    `styleParity`), chunk.bp (a page's files and pattern read through
│   │                    `routing`'s `conventions.classify` / `patternOf`), entry.bp (starters through jhonstart's
│   │                    `registerStarter`, the payload `s` check; components imported by
│   │                    their path inside the braces),
│   │                    script.bp, rebuild.bp, hooks.bp (RenderHooks over the tags),
│   │                    fixture.bp (the frozen fixture app every suite reads) — depends
│   │                    on onze and jhonstart
│   ├── onze-assets/   ← fronts 69 (owns root.bp + botopink.json) · 51 · 52: style_module.bp,
│   │                    stylesheet.bp, assets.bp (the two static roots), preprocess.bp,
│   │                    head.bp (pageRenderHooks), font_metrics.bp (the committed
│   │                    table — transcribed, generator owed), font.bp (googleFont over
│   │                    a FontBuild seam, localFont, fallbackFace, fontHead), image.bp
│   │                    (Image, the allowlist), image_handler.bp (the encoder port, the
│   │                    /_onze/image outcome) — depends on onze-bundler and jhonstart
│   ├── onze-og/       ← front 70 — both rows: card_style.bp (the closed subset —
│   │                    `style` is taken by jhonstart's element), metrics.bp (front 52's
│   │                    sidecars), layout.bp, svg.bp, raster.bp (the port; NIF
│   │                    declared, never shipped), response.bp — depends on jhonstart (it
│   │                    parses the sidecar text itself, so no onze-assets edge)
│   ├── onze-content/  ← front 121 — both rows (see its AGENTS.md): element.bp
│   │                    (the `markdown` library's tree as jhonstart's Element),
│   │                    collections.bp (loaders, typed entries, the sync and its
│   │                    store), feeds.bp (RSS 2.0); the Markdown reader is the
│   │                    `markdown` library's (decision 396); frontmatter arrives with
│   │                    step 3 — depends on markdown, jhonstart and validation;
│   │                    nothing imports it yet
│   └── onze-release/  ← front 71: spec.bp (ReleaseSpec, the build id), otp.bp (.rel,
│                        sys.config, vm.args, bin/onze, systools), docker.bp, package.bp
│                        (manifest completeness, the secret scan), lifecycle.bp (readiness,
│                        the shutdown order over a Lifecycle record), static_export.bp —
│                        depends on onze and onze-bundler
├── .gitignore         ← out/, .botopinkbuild/, .onze/ (a build's output); *.snap.new and
│                        *.snap.md.new (a snapshot mismatch's scratch file — the hook refuses
│                        one that is staged)
├── conformance/       ← the reference and its examples (decision 463): `docs.md` (onze.json, the alias map, the four seams, the not-built table) and `modules/<example>/` cells, run by `botopink cell check conformance/` (none yet)
├── examples/          ← blog/ (53: src/lib/db.bp — the post store —, content/posts/*.md,
│                        src/components/{nav,post_card}.bp, src/app/ — layout, page, blog/
│                        layout + page, blog/[slug]/page, (marketing)/about/page —,
│                        public/, test/{db,tags,render}_test.bp; [slug] and (marketing)
│                        compile only through `onze build`'s staged tree, and are served
│                        by `onze start` in onze-cli's start_test); scaffold/ (50: the
│                        committed output of `onze create scaffold --yes --libs ../../..`,
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
  restricts: `onze-server` is `["erlang"]` — its commonJS build fails on rakun's hosts (`rkReqLive`,
  `rkBeanStore`, … `have no #[@External] for the node backend`); the rest, `onze-cli` and `onze-og`
  included, run on both rows. Nothing on both rows imports rakun (every rakun manifest is
  `["erlang"]`, decision 117) — that is `onze-server`'s.
- One module cannot hold two types of one name: an `as` alias of an imported type still binds its
  declared name (`language-gaps.md`). `onze-server` constructs rakun's `App` and holds
  jhonstart's only as the core's `SiteRender` function value.
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
  members lists `modules/` and walks each member's own `src/` (`onze-assets`'s flush gate,
  `memberSources` in `test/stylesheet_test.bp`) — never a recursive walk of `..` or the root.
- Any code or layout change updates this file in the same commit.
