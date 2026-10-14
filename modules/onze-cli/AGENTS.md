# onze-cli

> Path: `repository/onze/modules/onze-cli/` · Parent: [`../../AGENTS.md`](../../AGENTS.md)
> Spec: `specs/1.0.10-beta/06-onze/50-onze-cli/README.md` in the meta repository

The `onze` command line, commonJS only — it runs on a developer's machine before any BEAM node
exists. `compiler-cli`'s shape: `main.bp` dispatches, one module per command, pure option parsers,
no parser drops a token.

| File | What |
|---|---|
| `src/resolve.bp` | `Project`, `findRoot` (walk up to `botopink.json`), `resolveProject` (config + aliases, errors naming their file) |
| `src/scan.bp` | `RouteEntry`, `scanFiles` / `scanApp` (what an app file is: `routing`'s `conventions.classify` / `ConventionFile`, decision 323; the pattern `routing`'s `patternOf(parsePath(…))`, `""` for a segment `pathProblem` refuses — that refusal already fails the scan; the decorator argument, the three refusals — authored paths only) |
| `src/generate.bp` | `checkTree` (a file's segment is `routing`'s `conventions.classify`), `stagedPath`, `rewriteImports` (an import `from "<alias>…"` — one line or several, up to its `;` — staged as the brace form of the app module the alias names, `import {lib.format.x};`: decision 206, `from` names a package; a `from` no alias names stays), `modFiles`, `routesModule` (the undecorated conventions' registrations, and an import of every decorated convention file — by its path inside the braces — so a program importing it runs their bodies first — decision 140), `stagedManifest` (relative `path` dependencies made absolute against the project root, extra dependencies added — a directory as `{ "path": … }`, a git URL as `{ "git": …, "branch": "feat" }` (`extraDep`)), `stage` / `stageAt` — the staged tree under `<outDir>/src/` |
| `src/create.bp` | `CreateOpts`, `createDefaults` (the one defaults record), `createHelp`, `parseCreateOpts` (`--src-dir` / `--no-src-dir`, the root layout by default; `--lang` into `onze.json`), `scaffoldLibraries(o)` (what the scaffold imports, and onze), `scaffoldFiles(In)`, `writeScaffold`, `mkdirs` |
| `src/info.bp` | `infoText`, `dependencyVersions`, `versionAt`, `tools` |
| `src/build.bp` | `buildProject(project, bin)` — the app's sources (`sourceOfApp`: no hidden directory, and no `test/` when `src` is the project root), scan, check, the client graph's refusals, the style modules (generated into the staged tree as `styles.<file>`), the staged server package (+ `onze_main.bp` and a dependency on onze-server, `memberBeside`: the member beside the project's `onze`) compiled for erlang into `<outDir>/server/erl/` and by `erlc` into `<outDir>/server/beam/` (`compileBeam`: the files dealt to one `erlc` per CPU, an equal share each — one `erlc` compiles serially on one scheduler, ~80 s for a scaffold's ~4 000 modules; a refusal is still erlc's own text and fails the build), the staged client package (+ the generated entry, and dependencies on the `jhonstart-link` / `jhonstart-forms` beside the project's `jhonstart`, and on `validation` as a git dependency resolved through the library roots — decision 326 — all three of which the entry imports) compiled for commonJS, the styleMap's probe run under node and under erl and compared (`BuildResult.styles`), the file-level link, the stylesheet, the build id, `static/<buildId>/`, `client-manifest.txt`, `build-id`; an absolute `outDir` is honoured; `srcDirOf`, `workspaceMembers` (a `{ "workspace": true }` dependency becomes a path in the staged manifest) |
| `src/start.bp` | `serverMainSource(config)` (the staged server's `main`: the resolved config as a literal, `PORT` over its port, the decorated conventions registered with jhonstart's `jhRegisterRoutes(@TypeInfo.all(with: page), …)` — decision 216 —, `Onze.run`), `startPort` (`-p`, then `PORT`, then `onze.json`), `serverCommand` (`erl -noshell -pa <outDir>/server/beam -eval '<package>@onze_main':main()` from the project root, output to `<outDir>/server.log`), `builtOutput` (no build → an error naming the directory), `spawnServer` (the background half a test drives), `startProject` (`onze start`, foreground) |
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
compiling), `start_test` (the port's precedence, the refusal of an unbuilt project, `onze build`
then the server over a real socket — the scaffold's `/`, the blog's `/blog/hello-world` and
`/about` — on a port the OS hands out (`freePort`: the gate runs the commonJS and erlang cells
side by side, so no port is written into the suite)). Every file a test writes is under `BOTOPINK_TEST_TMPDIR`.
