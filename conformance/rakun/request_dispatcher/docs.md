# request_dispatcher

The reference text this cell shows (from `conformance/docs.md`, § The dispatcher contract):

> `endRequest()` must run on the failure path too. The blob splits on `\n` into
> whole header values and a cookie value can never split it — `serializeCookie`
> percent-encodes a newline.
>
> | Phase | `headers()` | `cookies()` | `.set`/`.delete` | `after()` | marks dynamic |
> |---|---|---|---|---|---|
> | `Middleware` | yes | yes | yes | yes | no |
> | `Render` | yes | yes | **raises** | yes | yes |
> | `Action` | yes | yes | yes | yes | no |
> | `Handler` | yes | yes | yes | yes | yes |
> | `After` | yes | yes | **raises** | **raises** | no |

## Measured

The cell queues a cookie and a deferred `after` thunk in the handler and prints what `endRequest()` returns. The request id is a literal: there is no `newRequestId()` in rakun.
