# onze-content

> Path: `repository/onze/modules/onze-content/` · Parent: [`../../AGENTS.md`](../../AGENTS.md)
> Spec: `specs/1.0.12-beta/08-bpp/121-bpp-content/README.md` in the meta repository

The `markdown` library's tree (CommonMark 0.31.2 and the GitHub-flavoured extensions, read by the
library of decision 396) mapped to jhonstart's `Element`; content collections and an RSS feed. Steps 1–2,
4–5 of front 121; frontmatter (`frontmatter.bp`, step 3 — waits on `yaml`, front 142 step 2) arrives
later, and until then a `.md` entry under `glob` is a sync problem naming the step. Depends on `markdown`
(the reader and the `MdNode` tree, `{ "git": "https://github.com/botopink/markdown.git", "branch": "feat" }`;
onze-content is its one consumer, the maintainer's exception to 115), jhonstart (`Element`, `el`, `voidEl`,
`fragment`, `text`, `raw`), std and the library `validation` (a `#[validated]` type's `parse`, `Violation`;
declared in `dependencies` as `"validation": { "git": "https://github.com/botopink/validation.git",
"branch": "feat" }` since front 138 moved it out of the compiler); nothing in onze imports it yet.

| File | What |
|---|---|
| `src/element.bp` | `toElement(doc: MdDoc) -> Element` — the `markdown` library's tree as jhonstart's `Element` (raw HTML through `raw(…)`; a table cell's alignment as `style="text-align:…"`; a task item an `<input type="checkbox">`; the footnotes a `<section class="footnotes">` last). The parser, `toHtml`, `headings`, `slug` and the options are the library's |
| `src/collections.bp` | Content collections. `RawEntry(id, data: Json, body, filePath)`; `Loader = fn() -> @Task<@Result<Array<RawEntry>, string>>` — `glob(base, pattern)` (one `.json` object per file, id = the path under `base` without its extension, each segment slugged by the library's `slug`, a `slug` member overrides; a `.md` file is refused until step 3), `file(path)` (an array of objects, each with a unique non-empty `id`, taken out of the data), or the application's own function. `Collection<T>(name, loader, parse: fn(data: Json) -> @Result<T, ValidationReport>, references)` from `defineCollection(name, loader, { d -> T.parse(d) })` (the type is the only schema — validation's decisions 306, 327; 121 step 10 takes the type itself), `.reference(field, collection)` (the `// LANGUAGE GAP` form of `#[reference]`), `.erased() -> AnyCollection` (the parse kept as `check`). Readers: `getCollection`, `getCollectionWhere`, `getEntry` (`?Entry<T>`), `render(entry) -> Rendered(content: Element, headings)`; a read that meets an unreadable collection or an entry that does not decode panics naming it. The sync: `syncProblems(collections)` (every violation as `<file>: <path>: <message>`, a repeated id, a collection defined twice, a reference to a missing entry or an unsynced collection, a loader's own error), `writeStore(collections, outDir)` (refuses with every problem, else writes `<outDir>/content/<name>.json` — the data as the file wrote it); `useStore(outDir)` / `useFiles()` choose what `getCollection` reads (the process variable `ONZE_CONTENT_STORE`), `storeFile(outDir, name)` |
| `src/feeds.bp` | `RssFeed(title, description, site, items)`, `RssItem(title, link, description: ?string, pubDate: ?i64)`, `rssFeed(feed)` — RSS 2.0, every text node through std's `escape.html`, a link rooted at `/` made absolute against `site` (also the item's `guid`), a date as RFC 822 in GMT (`rfc822(epochMillis)`) |

Tests (`test/`, both rows): `element_test.bp` — the default options, `toElement` rendered with
jhonstart's `renderNode`; `collections_test.bp` — the loaders, the readers, the sync's problems,
references and the store, over content trees each test writes under `BOTOPINK_TEST_TMPDIR`
(`#[validated]` records of the test's own); `feeds_test.bp` — the whole document, escaping, the RFC 822
date. The CommonMark / GFM fixtures, the budget and the tree tests moved with the reader to the
`markdown` library (front 142 step 3).
