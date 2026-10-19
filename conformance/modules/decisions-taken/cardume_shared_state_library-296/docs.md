# Decision 296 — `cardume` is a library of its own

Shared state is `cardume`'s, a library of its own: `cartCount` is an `atom(0)` and `cartLabel` a synchronous `selector` over it, both imported from `"cardume"`, each identified by its declaration — no string key. Neither rakun nor `rakun-bpp` declares an atom; the store lives in rakun's bridge, `rakun-cardume`, one per request. The program enters a request, and `CartBadge` reads the selector with `use atomValue(cartLabel)` while `addToCart` writes the atom with `use atomSetter(cartCount)`, the same hooks the browser-side bridge spells over a page's store. The first render prints `0 items`; after two additions in the same request the second prints `2 items`; a new request starts from a fresh store and prints `0 items` again.

`Cookie<T>` is not cardume's: a cookie stays in `http` with its own hooks (400).

Cells of this repository that prove it: none yet. The `cardume` repository holds no code yet and rakun has no `rakun-cardume` bridge; both come with `09-cardume/136`, and the request store with 123 and `03-bundled-libs/104` step 6.

[draft/main.bp](draft/main.bp)
