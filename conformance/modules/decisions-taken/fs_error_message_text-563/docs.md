# Decision 563 — An `FsError` carries its own text: std's `io/fs` gives it `message()`

The program reads files through `readOr`, which turns an `io.fs` failure into its text with `e.message()` and no `case` over the error's variants — what rakun-ssr's content collections write. On a fresh directory it prints `not found: fs-error-563/missing.md`, `is a directory: fs-error-563` for reading the directory itself, `already exists: fs-error-563` for making it twice, then the written page's `# hello`, and `not a directory: fs-error-563/page.md/child.md` for a path through a file. Each text is `<what>: <path>`, the path as the program wrote it, the same on every target.

Cells of this repository that prove it: none yet — `2-libraries/150` (rakun-ssr) removes the local `fsText` helpers; `modules/rakun-ssr/src/content/collections.bp` already reads `e.message()`.

[draft/main.bp](draft/main.bp)
