# request_headers

{src/main.bp}

The reference text this cell shows (from [`../docs.md`](../docs.md), § `headers()`):

> `get` answers `?string` — `null` for an absent header, not `""`. Read it with
> `headerOf(h, name, fallback)` or bind the handle with its annotation
> (`val h: Headers = headers();`): the optional a record method answers loses its
> type when the receiver is itself a call, exactly as `paramOf` exists for in the
> file router. A name is case-folded, and a header sent twice answers both values
> joined with `", "`.
>
> Reading a header in phase `Render` or `Handler` marks the render dynamic;
> `dynamicReason()` names the first function that did it, and in a `strict` frame
> (front 60's prerenderer) the read raises instead, naming the function and the
> route.
