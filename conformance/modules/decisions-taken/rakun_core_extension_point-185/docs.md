# Decision 185 — When one rakun member has to tell or ask another and an edge between them would be a cycle or drag a member into consume

The example shows two optional members talking through the core with no edge between them.
`refreshPrices` stands for `rakun-cache`'s side: `revalidateTag("prices")` bumps the core's epoch
of the tag `prices` (`rkBumpTag`), and `rakun-cache` knows nothing of a REST client. `PriceClient`
stands for `rakun-restclient`'s side: when it caches a response it stores `rkTagEpoch("prices")`
beside it, and on the next call it compares the stored epoch with the current one — a changed
epoch is a miss, so the response is fetched again. `rakun-restclient` knows nothing of the cache.

`main` caches one response at epoch 0, reads it back as a hit, bumps the tag, and reads it again:
the epoch moved, the entry is stale, the client fetches. Neither member imports the other; each
imports only `rakun`, which owns the epoch and is the one place the two meet. A tag never bumped is
at epoch `0`, and an epoch only grows.

Proving cells: none in this repository yet; rakun-cache and rakun-restclient have no
`conformance/` features. They come with `04` step 1, `13` step 1 and `12` step 3.

[draft/main.bp](draft/main.bp)
