# The filter chain

> Package: [`rakun-service`](../docs.md) · index: [`../../docs.md`](../../docs.md)

`modules/rakun-service/` is a separate member. Depend on it with
`{ "rakun-service": { "workspace": true } }` inside the workspace, and call
`bootWeb()` once at startup — that installs the built-in entries, validates the
CORS policy and hands the runner to the host, so front 04's dispatcher finds it.

## One chain, two entry points

{filter_chain/src/main.bp}

{middleware/src/main.bp}

A filter that does not call `chain.next(req)` short-circuits, which is how a
security filter answers 401 without the handler ever running. A filter that
calls it may read what came back and answer something else.

**`#[order]` takes a string.** `#[order(-100)]` does not parse — a negative
integer literal in a decorator argument is a parse error on both targets — so the
number is quoted and parsed with `toI32`. See `AGENTS.md` § Language notes.

## The order band

`−400` request id · `−300` security · `−250` URL rules · `−200` CORS ·
`−150` API version · `−100` problem-detail boundary · `−50` `middleware.bp` ·
`0` application filters · `+100` metrics · `+200` compression ·
`+300` server identification. `orderBand()` answers the whole table.

## `Next`

`Next.pass()` continues the chain, `Next.redirect(url)` answers 307 with
`Location`, `Next.permanentRedirect(url)` answers 308, and `Next.rewrite(path)`
re-targets the route table while `req.path` keeps the URL the client asked for.
`pass()` and `rewrite()` answer status **0**, which is not a valid HTTP status
and never reaches the wire: the chain reads it as "continue".

## Response headers

{response_headers/src/main.bp}

`withHeader` returns the `Response` it was given and **replaces by name**,
case-insensitively. Two names are special: `Set-Cookie` is refused (queue cookies
with front 62's `cookies().set` and hand `endRequest()`'s blob to
`writeCookies`), and `Vary` is unioned rather than replaced.

## CORS

{cors/src/main.bp}

or, per controller:

{cors/src/main.bp}

With no policy nothing is allowed and no CORS header is ever set. The wildcard
together with `allowCredentials: true` fails at boot. A preflight for a path with
no route answers 404.

## Problem details

{problem_details/src/main.bp}

The tag is a **string**, not a type name: botopink has no typed raise and
`try … catch` works over `@Result` alone. A raise nothing handles answers 500
with `about:blank` and a correlation digest; the reason goes to the log under
that digest and never into the body.
