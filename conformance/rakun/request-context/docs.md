# The request context

> Package: [`rakun`](../docs.md) · index: [`../../docs.md`](../../docs.md)

`request_context.bp` is the server-side scope. Nothing else on the server can
reach the in-flight request: a `Request` lives only inside the function the
router dispatched to.

{request_context/src/main.bp}

`headersWire` is `name\tvalue` lines, `\n`-separated, names already lowercased
by the dispatcher. `endRequest()` must run on the failure path too, or the next
request on a keep-alive connection starts inside the previous one's frame.

`RequestScope` implements `@Renderable` (decision 354): a hook over the
request is written `-> @Component<T>`. The readers below are ordinary
functions, not hooks.

The scope is a FRAME with an EPOCH, not a process: a connection process serves
many requests in sequence, so every handle minted from the frame carries the
epoch it was minted with and raises if it is used after `endRequest` or from the
next request. Reading outside a request is a hard failure — `requestPhase()`
with no frame raises `request context is not established`, and there is no
lenient mode, no `…Or(default)` and no predicate to branch around it. A library
that has to work both inside and outside a request takes the values as
parameters.

The five phases are `Middleware`, `Render`, `Action`, `Handler` and `After`, and
the phase is stored once: front 12's `rkCachePhase()` reads this slot rather
than keeping a second one.

## The dispatcher contract

{request_dispatcher/src/main.bp}

`endRequest()` must run on the failure path too. The blob splits on `\n` into
whole header values and a cookie value can never split it — `serializeCookie`
percent-encodes a newline.

| Phase | `headers()` | `cookies()` | `.set`/`.delete` | `after()` | marks dynamic |
|---|---|---|---|---|---|
| `Middleware` | yes | yes | yes | yes | no |
| `Render` | yes | yes | **raises** | yes | yes |
| `Action` | yes | yes | yes | yes | no |
| `Handler` | yes | yes | yes | yes | yes |
| `After` | yes | yes | **raises** | **raises** | no |

## A scenario, end to end

{request_scenario/src/main.bp}

## `headers()`

{request_headers/src/main.bp}

`get` answers `?string` — `null` for an absent header, not `""`. Read it with
`headerOf(h, name, fallback)` or bind the handle with its annotation
(`val h: Headers = headers();`): the optional a record method answers loses its
type when the receiver is itself a call, exactly as `paramOf` exists for in the
file router. A name is case-folded, and a header sent twice answers both values
joined with `", "`.

Reading a header in phase `Render` or `Handler` marks the render dynamic;
`dynamicReason()` names the first function that did it, and in a `strict` frame
(front 60's prerenderer) the read raises instead, naming the function and the
route.

## `cookies()`

{request_cookies/src/main.bp}

A cookie may be written from a server action, a route handler or middleware; a
write in phase `Render` or `After` raises. The queued lines come back from
`endRequest()` as a `\n`-separated blob — the dispatcher appends each as its own
`Set-Cookie` header, because front 04's `rkSetReplyHeader` replaces by name and
so carries only one.

`cookieDefaults()` is `path="/"`, `domain=""`, `maxAge=0`, `httpOnly=true`,
`secure=true`, `sameSite="Lax"`. **Pass your own `maxAge`**: `Max-Age=0` expires
the cookie on arrival (RFC 6265 § 5.2.2), and `cookieDefaults()` carries it
because the front's acceptance pins the wire literal — see `AGENTS.md` for the
argument.

A cookie value is percent-encoded on the way out and percent-decoded on the way
in, over printable ASCII. A control character encodes (so a `Set-Cookie` line
cannot hold a newline) and never decodes back; a character above printable ASCII
is refused, naming the cookie — encode it yourself, base64url being the usual
answer.

## `draftMode()` and `connection()`

{request_draft_mode/src/main.bp}

`__rakun_draft` is a signed cookie; `enable()` needs `rakun.draft.secret` and
raises without it rather than issuing an unsigned bypass. Enabling marks the
request dynamic and sets the bypass flag front 60 reads. `connection()` marks
and reads nothing — the way a route declares itself dynamic without pretending
to need a header — and `dynamicReason()` names the first function that marked.

## `after()`

{request_after/src/main.bp}

The work runs once the response is sent, against a FROZEN copy of the frame
under phase `After`: it can read the request's headers and cookies and can write
nothing — a cookie write and a second `after()` both raise there. The dispatcher
calls `endRequest()`, writes the response, then `drainAfter(budget)`;
`rakun.request.after.timeout` (default 30 000 ms) bounds each thunk, and
`afterLog()` carries one line per failure or kill, each with the request id.

On the BEAM a thunk is a `spawn_monitor` child and an overrunning one is killed.
Node cannot interrupt a synchronous function, so it counts a thunk that overran
in the same slot — same counters, same log, one interruption real and one after
the fact.

## Per-request memoization

{request_memo/src/main.bp}

One table per request. A miss runs the loader and stores; a hit answers the
stored value and does not evaluate the loader at all; two requests with the same
key run it twice — a memo that survives a request is a cache, and caches belong
to front 12. `preload(key, load)` starts the load early (a spawned child on the
BEAM, an eager load on node) and a later `memoize` with that key waits for it
rather than starting a second one. `memoKey` does not hash and refuses a part
carrying its `|` separator.
