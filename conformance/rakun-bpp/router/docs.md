# The router

> Package: [`rakun-bpp`](../docs.md) · index: [`../../docs.md`](../../docs.md)

`router.bp` is a real module since front 26 of 1.0.10-beta; there is no
declaration file (decision 575 (1)). What a component asks for is a **route snapshot**: a five-field record
the server fills before the render and the client rebuilds after a client-side
navigation, so the same component code produces the same markup on both sides.

```text
pub type RouterState(
    path: string,                       // "/blog/hi"
    params: Array<#(string, string)>,   // [#("slug", "hi")]
    search: Array<#(string, string)>,   // [#("sort", "new")]
    pattern: string,                    // "/blog/[slug]"
    selected: i32,                      // the layout depth, root layout 0
)
```

{router_state/src/main.bp}

Field names and method names are **disjoint** — `params` is the field,
`param(name)` the method — so a field read never shadows a method.

| Call | Answers |
|---|---|
| `r.param(name)` | the path parameter, `""` when absent |
| `r.searchParam(name)` | the query parameter, `""` when absent |
| `r.segments()` | the pattern's segments, root-first, bracket spelling kept — `"/blog/[slug]"` → `["blog", "[slug]"]` |
| `r.segment()` | the segment at `selected`, `""` out of range |

Nothing returns `?string`. A matched route's parameter is always present and
`""` is the natural answer for one that is not — the shape `rakun`'s
`http.bp` accessors already use.

`segments` is **derived** from `pattern`, never transported. One value, one
source: a segment list that travelled separately could disagree with the
pattern it came from, and the disagreement would only show on the routes
nobody tested.

## `pairValue` — the package's one pair-list decoder

```text
pub fn pairValue(pairs: Array<#(string, string)>, name: string) -> string
```

The **first** match of a duplicated key, `""` when there is none. It is `pub`
and it is the only one: fronts 28 and 32 import it from here rather than each
growing a copy, because three implementations of "the value of `slug`, or the
empty string" is three chances to disagree about a duplicate key.

It is a `loop` over a typed parameter, not
`pairs.find({…}).unwrapOr(#("", ""))._1`. A tuple read off a value that came
back through the optional binder loses its type on the erlang row — the same
measurement that made rakun's front 22 spell `paramOf(m, name)` and front 23
`chunkAt(page, i)`. `patternSegments` and `segmentAt` are typed-parameter
readers for the same reason.

## The pair codec is std's `encoding` (decision 116 rule 4)

The two pair-shaped snapshot values (`m`, `q`), the request's four lists and an
island's props are decoded with std's `encoding.formParse` and written with
`encoding.formStringify` — the percent-aware form codec rakun uses on the
server. `q=a%20b` reads back as `a b` on both rows, `encoding.formParse("")` is
`[]` (never `[#("", "")]`), a field with no `=` is a name with an empty value,
and `formStringify` writes no leading `?`. The package carries no pair codec of
its own.

## The snapshot, the five cells and `fill`

```text
pub fn snapshot() -> RouterState
pub fn fill(path, params, search, pattern, selected) -> i32
```

`snapshot()` reads five host cells and builds the record. Each read maps
**one-to-one** onto a key of rakun front 23's payload envelope, so the record
the server builds and the record the client rebuilds are built from the same
five values:

| `RouterState` field | cell | payload key (front 23) |
|---|---|---|
| `path` | `__jhRoutePath()` | `p` — the pathname |
| `params` | `__jhRouteParams()` | `m` — querystring-encoded |
| `search` | `__jhRouteSearch()` | `q` — querystring-encoded |
| `pattern` | `__jhRoutePattern()` | `r` — the matched pattern, bracket spelling kept |
| `selected` | `__jhRouteSelected()` | — per-layout, supplied during the render |

The two pair-shaped values travel querystring-encoded. No JSON, no record
serialization, nothing that has to agree between an Erlang term and a JS
object. `snapshot()` performs no `?T` unwrap that can fail:
`encoding.formParse` answers `[]` for an empty string and every cell answers a
total value.

`fill` is the one writer, and it is `pub` **surface**, not an internal. The
five values go in together — a half-updated snapshot is a component reading the
previous route's params against the next route's pattern. A server adapter
calls it once per request; a client transition calls it with the values the
payload (`globals.payload`) carried, then re-renders. Nothing here is reactive: the router
is a snapshot, not a subscription.

Both halves ship with the package:

| row | host | store |
|---|---|---|
| commonJS | `src/router_runtime.mjs` | a module-global |
| erlang | `src/sidecars/jhonstart_router.erl` | the calling process's dictionary — a request is a process, the snapshot dies with it, and two concurrent renders cannot see each other's route |

An unfilled snapshot answers `""`/`[]`/`0` rather than raising: rendering a
component outside a request is a legitimate thing to do, and it is how the
package's own tests render the server pass.

**Every cell carries both targets.** The front's spec calls for the five reads
to be `#[@External.Erlang]` only; that is not writable. This module is compiled
on both rows of the core member, and an erlang-only cell reds the commonJS row
at its *call site* (`` `__jhRoutePath` has no `#[@External.<Target>(…)]` for the
node backend ``) the moment `snapshot()` calls it — a declared and never-called
cell is fine, which is why `client_runtime.bp`'s node-only `clientRender` does
not red the erlang row. The dual form is also what the mechanism needs: the
client rebuilds the snapshot on every transition and cannot do that through a
cell that exists only on the server.

## The six hooks

Next.js splits route state into five hooks over one internal record
(`useRouter`, `usePathname`, `useParams`, `useSearchParams`,
`useSelectedLayoutSegment(s)`). rakun-bpp spells them as **nouns** — the keyword
`use` is the activation and the name is the noun — so there is no `useRouter`
and never a doubled `use usePathname()`.

```text
pub fn router() -> @Component<RouterState>
pub fn pathname() -> @Component<string>
pub fn params() -> @Component<Array<#(string, string)>>
pub fn searchParams() -> @Component<Array<#(string, string)>>
pub fn selectedLayoutSegment() -> @Component<string>
pub fn selectedLayoutSegments() -> @Component<Array<string>>
```

`searchParams()` is the only way a page reads the query — `PageContext` has no
`query` field — and it marks the render **dynamic**, as `request()` does: the
payload's `d` is `true` only for a render that read either, so a cache may keep
every other render as static.

{router_hooks/src/main.bp}

The binding never reuses the hook's name (`val r = use router()`, never
`val router = …`): a local that shadows a module-level `pub fn` shadows it for
an importer too.

`selectedLayoutSegments()` answers **root-first**, because `pattern` is
root-first and `segments` is derived from it by dropping the empty parts —
nothing on the path reorders.

**`use` is not decoration.** A hook called *without* `use` answers its
`@Component<T>` — a Promise on commonJS, where every `@Component` body is an
`async function` — so an ordinary caller `await`s it (a `@Task` body or a
test):

```text
val ps = await params();
pairValue(ps, "slug")
```

Inside a `@Component` body `pairValue(use params(), …)` is exactly the array.

## The navigation verbs

botopink records are immutable and there is no assignment to a `self` field
anywhere in the tree, so navigation cannot be a method on `RouterState`. It is a
call against host state, and the record is a read-only snapshot of that state.
The six are free functions over one cell:

```text
pub fn push(href) -> i32       pub fn back() -> i32      pub fn refresh() -> i32
pub fn replace(href) -> i32    pub fn forward() -> i32   pub fn prefetch(href) -> i32
```

| Verb | erlang (during a server render) | js (in the browser) |
|---|---|---|
| `push(href)` | records a 307 redirect on the response | `history.pushState` + re-render |
| `replace(href)` | records a 307 redirect on the response | `history.replaceState` + re-render |
| `back()` / `forward()` | no-op — there is no history on the server | `history.back()` / `history.forward()` |
| `refresh()` | no-op | re-requests the current route's payload and re-reconciles without a reload |
| `prefetch(href)` | no-op | warms the client route cache; front 27 drives it |

The `-> i32` is the ecosystem's shape for a host cell whose value is not used
(`rakun/src/runtime.bp` does the same for `rkScan`/`rkEnter`/`rkDone`). It is
not a status code and callers ignore it.

```text
pub fn lastNavigation() -> string
```

What the last verb recorded, as `"<kind> <href>"`, and `""` when nothing has.
On the server this is the redirect a dispatcher turns into a 307; in the
browser it is the last href the History API was handed. It is `pub` because a
verb that records where nobody can look is a verb that does nothing.

A navigation never disturbs the snapshot: `fill` is the only writer of route
state, and the suite asserts that a `push` leaves the current `path` and
`params` exactly as they were.

`refresh()` hands the cell the value the library `actions` spells —
`refreshValue()` (decision 116 rule 2) — so the re-request header value is
written nowhere in this package.

## The envelope's navigation signal, and the route a URL is

```text
pub fn navigationFor(wire: string) -> string   // "" · "not-found" · "replace <location>"
pub fn applySignal(wire: string) -> i32        // performs it through the navigation cell
pub fn resolveRoute(table: string, path: string, search: string) -> RouterState
```

An action or refresh envelope's `n` field is read with `routing`'s
`navigation.signalFromWire` (decision 116 rule 1): `""` nothing, `"N"` the
nearest not-found, `"R|307|/login"` a `replace` to `/login`; a malformed `n`
reads as nothing, so a bad field from the network cannot crash a render. A
server action's `redirect` is rakun's and a page's is rakun-bpp's; the router
reads both through the same codec without importing rakun.

`resolveRoute` rebuilds the snapshot a client navigation needs: the table (the
payload's `t`, contract 1's wire) is read with `routing`'s `parseTable` and the
pathname matched with `matchPath` — the function rakun's server matches with.
The router has no matcher and no table parser of its own. An unmatched pathname
answers `pattern == ""` and no params.

## `clientApp` — a client-only app (`client_app.bp`)

```text
clientApp(routes: routeTable, mount: "#root", allowedRedirects: []).start()   // -> @Task<@Result<void, string>>
```

An application with no server runs the same pages under the router alone
(decision 117 rule 1). `routes` is contract 1's wire, read with `routing`'s
`parseTable` and matched with `matchPath`; `start()` composes the matched chain
(the UI registry's pages, layouts and conventions) with front 30's `compose` and
writes the markup into `mount` — the one browser write, `__jhMount`. A signal is
handled as the server render handles it: `notFound()` renders the route's
nearest not-found boundary with the URL unchanged; a relative `redirect(to)`
found in `routes` is the router's `replace(to)` (`history.replaceState`) and a
client navigation; an absolute one listed in `allowedRedirects` is
`location.replace(to)`; anything else fails `start()` and navigates nowhere.
With no `window` (node, the test row) the location and the mount are a module
store (`setClientLocation`, `mountedHtml`, `replacedLocation`).
