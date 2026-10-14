`Link(props, children)` renders an anchor the browser half drives. `linkProps`
fills Next's defaults (prefetch on, replace off, scroll on), and the
copy-with-one-field helpers such as `withPrefetch` change one of them; turning
prefetch off renders `data-jh-prefetch="0"`.
