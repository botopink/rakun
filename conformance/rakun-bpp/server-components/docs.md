# Server components

> Package: [`rakun-bpp`](../docs.md) · index: [`../../docs.md`](../../docs.md)

Promoted from `server.d.bp` (front 28). The declaration file listed three
blockers; all three are answered rather than carried. The async data layer is
**not** gated any more — `fn … -> @Task<T>` with a statement-level
`await` compiles and RUNS on both rows, `test` blocks included — `request()`
keeps a host half and now ships it, and the `Http` phantom `@Context` base and
the `Request` behavior are **gone** (see `AGENTS.md` § *The `Http` base, and why
it is gone*).

## `RequestData` — the request as a record

```text
pub type RequestData(
    method: string,
    path: string,
    params: Array<#(string, string)>,
    query: Array<#(string, string)>,
    headers: Array<#(string, string)>,
    cookies: Array<#(string, string)>,
)
```

{request_data/src/main.bp}

Six fields, every plural one an `Array<#(string, string)>` — the shape the route
snapshot uses, the shape `encoding.formParse` produces and the shape `Element.attrs`
takes, so a value read off the request is handed straight to an attribute with
no conversion. No `Dict`: naming `dict.Dict<string, string>` as a type across a
module boundary is unexercised anywhere in this tree, and the pair list is what
actually crosses the wire.

There is **no `body` field**, and its absence is a decision: a render never
reads one. Form bodies are front 24's and route-handler bodies are front 25's.

| Accessor | Reads | Absent key |
|---|---|---|
| `r.param(name)` | `params` | `""` |
| `r.queryParam(name)` | `query` | `""` |
| `r.header(name)` | `headers` | `""` |
| `r.cookie(name)` | `cookies` | `""` |

Every accessor answers a plain `string` and never raises. That is the
ecosystem's decided shape and not laziness — rakun's `Request` does exactly this
— because an optional would force `.unwrapOr` at every call site in every page.
All four funnel through front 26's `pairValue`, so "the value of `slug`, or the
empty string" cannot mean two different things in one package; a duplicated key
answers the FIRST match, in every accessor.

Field names and method names are **disjoint** — `params` the field, `param(n)`
the method, `query` the field, `queryParam(n)` the method — so a field read
never shadows a method. `method` and `path` are plain fields with no accessor:
there is nothing to look up by name in a single string.

## The six cells, and where they point

```text
pub fn enterRequest(req: RequestData) -> i32
pub fn leaveRequest() -> i32
pub fn request() -> @Component<RequestData>
pub fn cookies() -> Array<#(string, string)>
pub fn headers() -> Array<#(string, string)>
```

`enterRequest(req)` is the one writer and `leaveRequest()` its pair. Front 30's
render calls both, once per render, with the `RequestData` rakun-ssr handed it
(decision 114 item 8); outside `server.bp` and `render.bp` nothing in `src/`
calls either. Between the two, `request()`, `cookies()` and `headers()` read
the entered request; **outside** them they raise — there is no request to read,
and an empty one would be a silent wrong answer. A component that must render
with no host takes a `RequestData` parameter instead.

The four pair lists are stored `k=v&k=v` with std's `encoding.formStringify`
and read back with `encoding.formParse` (decision 116 rule 4), so a cookie or
query value carrying `%20` reads as a space here exactly as it does in rakun.
No JSON, no record serialization, nothing that has to agree between an Erlang
term and a JS object.

The cells name **`jhonstart_server`** / **`./server_runtime.mjs`**, not front
62's `rakun_request_context`, and both halves ship with the module
(`src/sidecars/jhonstart_server.erl`, `src/server_runtime.mjs`) exactly as the
router's do. Two measurements force it, and `AGENTS.md` § *Why the request cells
are rakun-bpp's own* carries them: an erlang-only cell reds the **commonJS
compile** at its call site, and rakun-bpp imports no rakun module
(decision 113). Six values go in at once, never one at a time, because a
half-updated request is a component reading the previous reader's cookie
against this reader's path.

It is **not** the router's `fill` under another name and the two stores stay
separate on purpose: a route snapshot is re-filled DURING a render (its
`selected` is the layout depth and changes per layout) while a request is
entered once and is constant for the whole render.

`after()`, `connection()`, `draftMode()` and per-request memoization are front
62's and are called from there directly. `cookies()` and `headers()` are the
only two shortcuts re-exported here.

`request()` is a hook, `pub fn request() -> @Component<RequestData>`, activated `val r = use request()` inside a server component whose
return is `@Component<Element>` (decisions 104/128 of botopink
1.0.10-beta). Called without `use` it answers the same `@Component` — a Promise on
commonJS — so a `@Task` body or a test `await`s it.

## The server-component convention

A server component that only loads data is a `pub fn` taking its route params
and returning `@Task<Element>`. There is no decorator for it and there will not
be one — the marker is the return type itself (decision 118 of botopink
1.0.10-beta: the return is the annotation), and the language enforces it:

| Written | Compiler says |
|---|---|
| `pub fn f() -> i32 { val p = await loadPost("x"); … }` | `effect-await-without-task` — `await` needs a `@Task` return or above |
| `fn Page() -> @Task<Element> { val c = use state(0); … }` | `use-without-context-effect` — `use` needs a `@Component` return |
| `fn Page() -> @Component<Element> { val p = try await load(); … }` | `effect-try-without-fallible-channel` — `Element` is not a `@Result` |
| any of the six removed effect annotations on a fn | `effect-annotation-removed` (decision 127) |

Row two is why the chain matters: a server component that activates a hook
is `fn … -> @Component<Element>` — `@Component` extends `@Task`, so
the one return grants `use` and `await` (decision 128 of botopink 1.0.10-beta;
a `@Task` body activates nothing). `renderComponent` renders its thunk. Both are
asserted in `test/server_test.bp`.

Row three is the rule a page has to design for: **a component does not
propagate errors** (decision 121). Only `@Result` fails, and a component returns
`Element`, so a failed load is handled in the component's own body — `try … catch`
with a fallback, a `case` over the `@Result`, or an error screen:

{server_component_catch/src/main.bp}

```text
pub fn renderServerComponent(component: fn() -> @Task<Element>) -> @Task<string>
pub fn renderComponent(component: fn() -> @Component<Element>) -> @Task<string>
```

Awaits exactly once and renders synchronously afterwards. The parameter is an
**unstarted thunk**, not an already-running `@Task<Element>`, so a page that
grows a second loader moves to front 02 without changing what it hands anybody.

> **Call it with a lambda, never with a bare function name.**
> `renderServerComponent({ -> Page(params) })` is green on both rows;
> `renderServerComponent(Page)` compiles on commonJS and fails
> `variable 'Page' is unbound` on erlang. A bare function name used as a value
> is a compiler defect, measured against `2e6bb4ac` and reported, not worked
> around. It is the same rule rakun's front 23 records for the fields of its
> `ElementView`.

## The loader convention, and why `@Task` being eager changes it

A loader is an ordinary `fn name(args) -> @Task<T>` — or `@Task<@Result<T, E>>`
when it can fail, in which case its body may `throw` / `try` and its caller
writes `try await` (to propagate, from a `@Result`-returning caller) or
`try await … catch …` (from a component). `server.bp` ships **no** loader
machinery: `libs/std/src/http.bp` already has `fetch(url)`, a database loader is
front 08's, and parallel awaiting (`all`, `race`, `allSettled`) is **front 02's**.

**Every `await` is at statement level**, in the component or loader body. Never
as the last statement of a lambda: `§2.38` makes a lambda's last statement an
implicit-return expression and no file in this tree awaits inside one. So a
component that needs N rows awaits **one** loader returning `Array<T>` and maps
synchronously afterwards — not N awaits inside a `map`.

{server_component_sequential/src/main.bp}

**`@Task` is EAGER on the erlang row** (decision 120 of botopink 1.0.10-beta;
`libs/std/src/http.bp:16-18`): a `@Task<T>` resolves to `T` and the caller's
`await` is identity on that backend. Two `@Task` loaders do
**not** load in parallel because they are Tasks — they run in the order the
body reaches them and the page costs the **sum** of its loaders. Porting the
Next.js pattern shape-for-shape and stopping there produces a page slower than
the synchronous version.

The two above are **dependent** (`loadComments` needs `post.id`), so sequence is
what they actually are. When loaders are **independent** the answer is front
02's spawn-and-gather over **unstarted tasks** —
`[{ -> loadPost(slug) }, { -> loadSidebar() }]` — never a `map` over Tasks,
which would simply run them in order. rakun-bpp provides no second answer and
exports no `awaitAll`-style helper.

## Escaping is not this file's

`renderToString` writes `e.value` and every attribute value straight into the
output (`element.bp:56`, `:63-65`) and neither escapes. A server component
renders attacker-influenced text — a post body, a comment, a search term echoed
back — so every such value goes through front 01's `escape.html` (text) and
`escape.attribute` (attribute values) **at the point the untrusted value enters
the tree**. `server.bp` hand-rolls no escaping and re-exports none: front 01's
`libs/std/src/escape.bp` does not exist in compiler `2e6bb4ac` yet, and a
stand-in here would be a second answer to "what is an escaped `&`" the day it
lands. `test/server_test.bp` pins the unescaped answer so the change is a red
cell rather than a silent difference.

The payload (`globals.payload`) is front 23's to build and to escape. Nothing from
`server.bp` crosses to the client: a value read from a header or a cookie must
not be reachable from an island's props, and the check that it is not is front
68's build-time graph walk.
