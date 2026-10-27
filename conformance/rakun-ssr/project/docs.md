# What rakun-ssr owns

> Package: [`rakun-ssr`](../docs.md) · index: [`../../docs.md`](../../docs.md)

Five things, and nothing that duplicates a rakun or rakun-bpp definition:

| Piece | Where | What |
|---|---|---|
| `OnzeConfig` | `modules/rakun-ssr/src/config.bp` | the project configuration `rakun-ssr.json` holds — `defaultConfig()`, `withPort` / `withDev`, `loadConfig(botopinkJson, onzeJson)` (an unknown key, a wrong kind or a port outside `1..65535` is an `Error` naming the key), `parsePort(text, source)` (a `PORT` / `-p` value), `describeConfig` (the table `rakun-ssr info` prints) |
| the routing-file table | `modules/rakun-ssr/src/types.bp` | `OnzeProject`, `describeAppFiles(appDir, paths)` — over the `routing` library's `conventions` (`ConventionFile(authoredPath, segment, kind)`, `fileKinds()`, `classify(appDir, path)`; decision 323), which say what an app file is |
| the environment rule | `modules/rakun-ssr/src/config.bp` | `publicEnvPrefix`, `isPublicEnvName`, `publicEnv` |
| the boot adapter | `modules/rakun-ssr/src/integration.bp` (both rows) and `modules/rakun-ssr/src/server/server.bp` (erlang) | the rakun-bpp half — `bootSite`, `siteRender`, `rakunEntries`, `responseOver`, `chainFor`, `pageInput`, `boot` — and the rakun half: `Onze.run(config)`, `requestData`, `responseFor`, `registerPages`, `registerRoots` |

## `rakun-ssr.json`

| Key | Default | Meaning |
|---|---|---|
| `name` | `botopink.json`'s `name` | the project name |
| `port` | `3000` | the listener's port |
| `basePath` | `""` | passed to rakun's `App` unchanged — rakun-ssr does not reimplement prefixing |
| `appDir` | `"app"` | written into rakun as `rakun.appDir`; `"src/app"` is the same mechanism with another string |
| `publicDir` | `"public"` | served verbatim at `/` |
| `outDir` | `".onze"` | the build output |
| `dev` | `false` | development mode |
| `actionsBodyLimit` | `1048576` | bytes; written into rakun as `rakun.actions.bodyLimit` (decision 117) |
| `allowedRedirects` | `[]` | absolute redirect targets rakun-bpp accepts; handed to `app(allowedRedirects: …)` |
| `lang` | `"en"` | the document's `<html lang>`; handed to `app(lang: …)`, which refuses a value that is not a language tag |

## Imports

Import aliases do not exist (decision 1050): `import {readPost} from "@/lib.db";` is refused like any unresolved import. A module of the package is imported by its path inside the braces — `import {lib.db.readPost};` (decision 206) — and `rakun-ssr` rewrites no import text before the compiler reads it, so a project that builds under `rakun-ssr` passes a bare `botopink check`. An `alias` key in `botopink.json` is an unknown manifest key and is refused.
