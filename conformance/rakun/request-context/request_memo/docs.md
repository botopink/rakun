# request_memo

{src/main.bp}

The reference text this cell shows (from [`../docs.md`](../docs.md), § Per-request memoization):

> One table per request. A miss runs the loader and stores; a hit answers the
> stored value and does not evaluate the loader at all; two requests with the same
> key run it twice — a memo that survives a request is a cache, and caches belong
> to front 12. `preload(key, load)` starts the load early (a spawned child on the
> BEAM, an eager load on node) and a later `memoize` with that key waits for it
> rather than starting a second one. `memoKey` does not hash and refuses a part
> carrying its `|` separator.
