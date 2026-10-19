# Decision 292 — The string instructions left after 278 go, each to its own place.

The navigation bar says how each link navigates with an annotation inside its tag, never with a string attribute. `<a href="/legacy" #[reload]>` asks for a full document load. `<a href="/search?q=bpp" #[history(.Replace)]>` replaces the history entry, the other cases of `History` being `.Push` and `.Auto`. Each annotation records its typed meta (`LinkReload`, `LinkHistory`), and `rakun-bpp`'s `html` lowers it to the runtime's `data-jh-reload` / `data-jh-history` attributes in the printed HTML. The author never writes those attributes.

`SwapLogger` is a `#[client]` component. It subscribes to two of the five navigation events, `onBeforeSwap` and `onPageLoad`, through `#[clientOnly]` hooks with typed events. `onBeforePreparation`, `onAfterPreparation` and `onAfterSwap` are the other three. The `jh:` DOM event names stay the runtime's wire. The same hooks are refused outside a `#[client]` component. `<Script src="/analytics.js" strategy={.LazyOnload} />` picks its loading strategy from its own enum, `ScriptStrategy` (`BeforeInteractive`, `AfterInteractive`, `LazyOnload`, `Worker`), kept apart from the islands' `Hydrate`. The program prints the rendered navigation as one line.

Cells in this repository that prove it: none yet. `rakun-bpp/client-navigation/link_props` shows today's `Link` props. The annotations and hooks arrive with front 150 s43 (view transitions), and `<Script>`'s enum with s60 step 10.

[draft/main.bp](draft/main.bp)
