# What rakun-ssr owns

> Package: [`rakun-ssr`](../docs.md) · index: [`../../docs.md`](../../docs.md)

Five things, and nothing that duplicates a rakun or rakun-bpp definition:

| Piece | Where | What |
|---|---|---|
| `OnzeConfig` | `modules/rakun-ssr/src/config.bp` | the project configuration `rakun-ssr.json` holds — `defaultConfig()`, `withPort` / `withDev`, `loadConfig(botopinkJson, onzeJson)` (an unknown key, a wrong kind or a port outside `1..65535` is an `Error` naming the key), `parsePort(text, source)` (a `PORT` / `-p` value), `describeConfig` (the table `rakun-ssr info` prints) |
| the import alias map | `modules/rakun-ssr/src/types.bp` | `AliasMap`, `loadAliases(botopinkJson)` (a target that escapes the package root is refused at load, naming the entry), `resolveAlias(map, spec)` (longest prefix first, at a module boundary) |
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

## The import alias map

```json
{ "name": "blog", "alias": { "@/components": "components", "@/lib": "lib" } }
```

`import {PostCard} from "@/components.post_card";` resolves to `components.post_card`, a module of
the app, and is staged as `import {components.post_card.PostCard};` — the compiler's `from` names a
package only (decision 206), and a module of the package is imported by its path inside the
braces, which is also how an app module imports another without an alias. The mechanism is textual
and build-time: `rakun-ssr`'s staging rewrites the import before the compiler sees it. **The compiler does not know aliases exist**, so an alias is visible through
`rakun-ssr build` only — a bare `botopink check` on the source tree does not resolve it.
