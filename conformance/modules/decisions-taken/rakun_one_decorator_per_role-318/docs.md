# Decision 318 — One decorator per role, in rakun's own names; Spring's synonyms go.

An order service written with one decorator per role. `OrderStore` is a hand-written store, so it is a `#[component]` — the one type stereotype; there is no `#[service]`, `#[managed]` or core `#[repository]` on a type. The clock is provided by a free function, `#[provides] fn clock(cfg: AppConfig) -> Clock`, reading the typed config record `AppConfig`; there is no `#[configuration]` class with `#[bean]` methods. `Orders`, another `#[component]`, takes both by type, and its `place` method is wrapped by `#[transactional]` — added behaviour is a wrapper on the function, not a hand-written proxy type. The destination `orders` is declared once and typed, `Destination<OrderPlaced>("order-events")`, and `Audit.record` listens to it with `#[listen(orders)]`. `Inventory` is an HTTP client: `#[httpClient(InventoryConfig)]` generates the implementation of the `behavior`, its `#[get("/stock/${sku}")]` hole the method's parameter. `OrderController` is the one controller: `byId` answers a record, so the answer is JSON; `health` answers a `Response`, sent as is. `main` dispatches two requests and prints each status and body.

Spring's synonyms are not there to choose from: `#[restController]`, `#[configuration]` / `#[bean]`, `#[httpExchange]`, `#[kafkaListener]` and the type-level `#[listener]` are gone, not aliases of these.

Cells of this repository that prove it: none yet. `rakun/container/provides` shows `#[provides]` on a free function and `rakun/web/usage` still declares `#[service]` and `#[restController]`; the rest comes with rakun 04, 08, 12, 13, 15, 19, 79, 91 and 93 (130 step 5).

[draft/main.bp](draft/main.bp)
