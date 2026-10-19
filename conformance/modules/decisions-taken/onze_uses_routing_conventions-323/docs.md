# Decision 323 — `chainFor(patterns)` keeps taking the ancestor patterns rakun's layout chain names for the matched route — onze derives

`rakun-ssr` (once onze) classifies an application's files through the `routing` library's `conventions`. The program hands `describeAppFiles` a small `app/` tree — the root page and layout, a `blog/[slug]` page with its own `loading`, a private `_components/` file and a stray `utils.bp` — and prints the table: each path's segment and kind exactly as `conventions.classify` answers them, the private folder and the non-convention file carrying no kind. No file-kind list of `rakun-ssr`'s own is read; `appFileKinds()` and `classifyAppFile()` are gone.

The second half shows the layout chain: `chainFor` takes the ancestor patterns rakun's chain names for the matched route `/blog/[slug]` — `/`, `/blog`, `/blog/[slug]` — and answers one segment per pattern, root first; `rakun-ssr` derives no chain of its own. The program prints `3`.

Cells of this repository that prove it: none yet. `modules/rakun-ssr/test/types_test.bp` records the table against `conventions.fileKinds` / `conventions.classify`, and `modules/rakun-ssr/test/integration_test.bp` runs `chainFor`; the reference row is `rakun-ssr/project/docs.md`.

[draft/main.bp](draft/main.bp)
