# rakun-service — the filter chain and TLS on the web layer

> Package: [`modules/rakun-service/`](../../modules/rakun-service/) · index: [`../docs.md`](../docs.md) · core: [`../rakun/docs.md`](../rakun/docs.md)

`rakun-service` is the web layer beside the core: one ordered chain of entries
between the socket and the route handler, CORS, RFC 9457 problem details, and
the listener's side of the SSL bundles `rakun` resolves. Its cells depend on
`rakun` through the feature's workspace and on `rakun-service` through their own
`deps/`.

## Features

Each feature is a directory, `conformance/rakun-service/<feature>/`: its `docs.md`
says what the feature does and links the cells beside it.

| Feature | What it shows |
|---|---|
| [The filter chain](filter-chain/docs.md) | `#[filter]`, `#[middleware]`, response headers, CORS, problem details |
| [TLS on the web layer](tls/docs.md) | the listener's bundle, the peer subject, HSTS |
