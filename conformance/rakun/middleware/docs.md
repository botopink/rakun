# middleware

The reference text this cell shows (from `conformance/docs.md`, § [order("-10")]):

> A filter that does not call `chain.next(req)` short-circuits, which is how a
> security filter answers 401 without the handler ever running. A filter that
> calls it may read what came back and answer something else.
>
> **`#[order]` takes a string.** `#[order(-100)]` does not parse — a negative
> integer literal in a decorator argument is a parse error on both targets — so the
> number is quoted and parsed with `toI32`. See `AGENTS.md` § Language notes.

## Measured

The cell puts the `#[middleware]` function in `main.bp` (the original file was `middleware.bp` at the project root).
