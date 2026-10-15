# Error boundaries

> Package: [`rakun-bpp`](../docs.md) · index: [`../../docs.md`](../../docs.md)

Front 31. A boundary is a recovery point: its child is a **thunk** answering
`@Result<Element, string>`, and the boundary is a `case` over what it answered.

```text
pub type ErrorInfo(message: string, digest: string)
pub type ErrorBoundary(id: string, fallback: fn(info: ErrorInfo) -> Element,
                       child: fn() -> @Result<Element, string>)

pub fn renderBoundary(b: ErrorBoundary) -> Element                        // re-raises a signal
pub fn renderBoundaryChecked(b: ErrorBoundary) -> @Result<Element, string> // Error(reason) for a signal
pub fn catchError(id, fallback, child) -> ErrorBoundary                   // the constructor, readably
pub fn infoFor(message) -> ErrorInfo        // message "" + digest — what a fallback renders
pub fn serverInfoFor(message) -> ErrorInfo  // message + the same digest — the logger's only
pub fn digestOf(message) -> string          // std's hash.contentHash
pub fn wrap(id, tree) -> Element            // <div data-jh-e="ID">…</div>
pub fn resetAttr(id) -> #(string, string)   // #("data-jh-reset", ID)
pub fn notFound() -> string                 // raises nav:not-found
pub fn redirect(url) -> string              // raises nav:redirect:<url>
pub fn isSignal(message) -> bool            // routing's isSignalReason
```

{error_boundary/src/main.bp}

The thunk is called **exactly once**, through the one host cell that turns a
raise into a value (`__jhCapture`, `signal_runtime.mjs` /
`sidecars/jhonstart_signal.erl`): a returned `Error`, a thrown one and a
component that crashed all reach the fallback. No client-visible `ErrorInfo`
ever carries a message — the digest is what the reader reports and what the log
line carries.

**A boundary around a component is a node** (decisions 388, 414). A component at run
time is a lambda over a `RenderScope`: calling it runs nothing, so a try catches a
component only around its run, and only a function holding the scope can write one.
A composition's `error` and `not-found` segments, and an application's
`errorBoundaryNode(id, { -> Panel() }, fallback)`, place a node in the tree
(`render.bp` `ErrorBoundaryNode`, `NotFoundBoundaryNode`, beside `suspense.Boundary`);
the renderer's plain functions — `renderComponent(c, scope)`, `renderErrorBoundary`,
`renderNotFound` — run each inside the host's try with the scope its parent's `run`
answered, and the stream fills each `Suspense` hole with the scope it was registered
under (`Fill`). The root runs with `RenderScope.root()`.

```text
pub fn renderComponent(c: @Component<Element>, scope: RenderScope) -> @Task<Walked>
pub fn errorBoundaryNode(id: string, child: fn() -> @Component<Element>,
                         fallback: fn(info: ErrorInfo) -> Element) -> Element
```

**Signals are not errors.** `notFound()` and `redirect(url)` raise the `nav:`
reasons of `contracts.md § 5b`, spelled by `routing`'s `navigation` (this file
writes no `nav:` literal). A page, layout or template writes the call
(`notFound();`) — a `@Component` body cannot `throw` — and a `@Result` thunk may
write `throw notFound();`; both raise. A boundary re-raises a signal instead of
rendering a fallback; front 30's render turns it into a 404 / 307 before the
first chunk and `data-jh-g` markup after it, and front 26's `clientApp` does the
same in the browser.

| File | Exports | Rendered when | Owns its document? |
|---|---|---|---|
| `error.bp` | `pub fn ErrorPage(info: ErrorInfo) -> Element` | the segment's subtree answers `Error(…)` | no |
| `not-found.bp` | `pub fn NotFound() -> Element` | a not-found signal reaches the segment | no |
| `global-error.bp` | `pub fn GlobalError(info: ErrorInfo) -> Element` | the root segment fails, or no other boundary caught | **yes** — `htmlTag` and `body`, front 94's |

`ErrorPage`, never `Error`: `Error(error: E)` is the `@Result` variant, and a
module-level `pub fn Error` would shadow it in every `case` arm of the file.

The browser rules (fronts 29 and 68 implement them):

1. A `[data-jh-e="ID"]` element is the catch target — a client component that
   throws during render is replaced by the nearest one's fallback, from the
   same `ErrorInfo` shape.
2. **Event-handler errors are not caught**: a handler is a `data-jh-on-click`
   attribute, outside the `@Result` channel by construction.
3. **`startTransition` errors are caught**: front 68's runtime routes the
   failure to the nearest `data-jh-e`, with a digest computed the same way.

`data-jh-reset="ID"` is the fallback's reset control — inert in the server HTML,
bound at hydration to front 26's `refresh()`. An action envelope with
`ok: false` is **data**, handled by front 67's form state, and never reaches a
boundary; a boundary sees an action only when the POST itself raised.
