# rakun-bpp — reference

> A React/Next-style UI framework written in botopink, on the language's own
> primitives. Status: **core + hooks + the element surface + the `html` markup
> DSL implemented in real `.bp`** (`Element` tree, builders, the forty-six HTML
> constructors, synchronous `renderToString`, the
> `state`/`effect`/`memo`/`ref`/`reducer` family, and the `html """…"""` authoring
> DSL — all compiled & runtime-tested). **No `.d.bp` remains**: 1.0.10-beta's
> front 26 promoted `router.d.bp`, front 28 promoted `server.d.bp`, and front 27
> landed `link.bp`/`reconcile.bp` as real modules. What is still gated is the
> *client* half — the delegated click handler, prefetch, link status and the
> reconciler driver — and it waits on rakun-ssr front 68's generated bundle and rakun
> front 60's route-kind table, not on a language gap (see **V1 limits**).
> Specs: `tasks/v0.beta.7/specs/jhonstart.md`,
> `tasks/v0.beta.8/specs/rakun-bpp.md`.

## Loading

`repository/rakun-bpp/` is a **workspace** (`"workspaces": ["modules/*", "examples/*"]`,
decision 75 of 1.0.10-beta); the library is its member `modules/rakun-bpp/`, and
`from "rakun-bpp"` resolves to that member, never to the umbrella. Declare it as
a dependency — `dependencies` is the object form, exactly one source per entry
(decision 76) — and import what you need:

```jsonc
// botopink.json
{ "name": "myapp", "target": "commonJS", "src": "src/", "entry": "main.bp",
  "dependencies": { "rakun-bpp": { "git": "https://github.com/botopink/rakun.git", "branch": "feat" } } }
```

```jsonc
// …or, from a sibling member of rakun-bpp's own workspace — which is what
// examples/jhonstart-{counter,markup,todo}/ use:
{ "dependencies": { "rakun-bpp": { "workspace": true } } }
```

<!-- example: imports_surface -->

The loader walks up from `cwd` and, at each ancestor, considers these roots
(nearest-first): the ancestor itself when its `botopink.json` is a workspace,
`repository/botopink-lang/libs`, `repository/`, a legacy flat `libs/`, then
`.botopinkbuild/deps/`. A root contributes every immediate child holding a
`botopink.json` **and every member of a workspace found there, named by its own
manifest** — so `repository/` contributes `rakun-bpp` (the member
`repository/rakun-bpp/modules/rakun-bpp/`), `rakun-bpp` (the DSL member),
`rakun-bpp`, `jhonstart-counter`, `jhonstart-markup` and `jhonstart-todo`,
and never the umbrella. Each member's `files` — the core's `root.bp`,
`element.bp`, `hooks.bp`, `router.bp`, `elements.bp`, `client_runtime.bp`,
`server.bp`, …; `rakun-bpp`'s `root.bp`, `html.bp` — are the only modules a
consumer sees. A
`{ "workspace": true }` dependency consults no root at all. Nothing about
rakun-bpp is embedded; the compiler core never names it.

## Component model

A **component** that activates hooks is a `fn(...) -> @Component<Element>`
(one that activates none is an ordinary `fn … -> Element`). A **hook** is a
function named by its **noun** — `state`, `effect`, `memo`, `ref`,
`reducer`, `router`; never a `use` prefix in the name — returning
`@Component<_>`. There is no annotation: **the return type is the
effect** (decisions 118 and 128 of botopink 1.0.10-beta). `Element` carries the
tree: `implement @Renderable`. The keyword `use` is the activation:
`val c = use state(0)` is legal only in a body whose return is
`@Component<_>` — a component or a custom hook — and every
`use` sits in the body's **static prefix** — before any `if`, `case`, `loop` or
`return`, at any nesting. A body with any other return that activates a hook is
`use-without-context-effect`. All of this is the language's context-inference
(decisions 88, 104, 118, 128 of 1.0.10-beta), not rakun-bpp. `@Component`
extends `@Task`, so a component or hook may also `await`; it may `throw` / `try`
only when its `T` is a `@Result` — a component returns `Element`, so it handles
errors in its own body (`try … catch`, `case`; decision 121). On commonJS every
`@Component` body is an `async function`: a component's caller `await`s it.

<!-- example: counter_ssr -->

Children are written as a **list** (`div([a, b])`). A hook yields its value via
`use`: `val c = use state(0)` binds `c : State<i32>` (`c.value`, `c.set(n)`); the
`{value, set}` form also destructures — `val {value, set} = use state(0)`. A
binding never reuses the hook's name (`val r = use router()`, not `val router`).
Called **without** `use`, a hook is an ordinary call — the first-render value —
legal in any body; that is how the tests read the hooks.

## Hooks

Hook **bodies are pure and synchronous** — they model the first render (the
server pass): `state` yields its initial value, `memo` computes eagerly,
`effect` is a no-op, `ref`/`reducer` seed their boxes. `use f(x)` lowers to
`f(x)` on **every** backend — nothing is renamed to React's `useState`, no
dependency array is inferred (a hook that takes one declares it: `memo(compute,
deps)`). Client re-render reactivity is the **client runtime**'s job: see
*Client runtime* below.

| Hook | Returns (via `use`) | Notes |
|---|---|---|
| `state<T>(initial)` | `State<T>` = `{value: T, set: fn(next: T)}` | local state + setter |
| `effect(run, deps)` | `#()` | side effect after render (void) |
| `memo<T>(compute, deps)` | `T` | memoized value (computed eagerly in SSR) |
| `ref<T>(initial)` | `#(current: T)` | mutable handle |
| `reducer<S,A>(reduce, init)` | `#(state: S, dispatch: fn(action: A))` | reducer state |

Custom hooks compose the primitives — a noun for a name and a
`@Component<_>` return:

<!-- example: hook_noun_custom -->

## Client runtime

The client build resolves `rakun-bpp/hooks` to `rakun-bpp/client_runtime.mjs`
(`modules/rakun-bpp/src/client_runtime.mjs`, shipped next to the emitted modules
by `botopink build`): the same five nouns, the same signatures and shapes, over rakun-bpp's
own minimal render loop — cursor-indexed cells (the static-prefix rule is what
keeps the order stable), `set`/`dispatch` schedule one re-render per microtask,
effects run after commit when their `deps` change; `render(component, commit)`
drives a component and hands every committed tree to `commit`. Outside a render
every cell yields its first-render value, so the module is a drop-in for the
pure bodies. The substitution itself is the client bundler's step (front 68,
1.0.10-beta); under node it is a `require.cache` seed — `examples/jhonstart-
counter/client.mjs` runs the built `Counter` that way and prints the re-renders
after `set(3)` and `set(-2)`. `modules/rakun-bpp/src/client_runtime.bp` carries
the one bp-typed cell, `clientRender`, whose
`#[@External.Node("./client_runtime.mjs", "render")]`
is what makes the CLI ship the sidecar (a miss is silent — see `AGENTS.md`
§ Known defect); the five nouns are not re-declared in
bp, because a package's import surface is flat and a second `state` would
shadow `hooks.state` for every consumer.

## DOM builders & rendering

`text(value)` is an explicit text node; `fragment(children)` groups siblings
with no wrapper; `div`/`span`/`p`/`h1`/`ul`/`li` are element builders. Each takes
a `Children` argument, so the call site can pass a **list** (`div([a, b])`), a
single `Element`, or a `string` (the G4 coercion). The **list form is what V1
renders** (and what the `html` DSL emits); a lone-child / `string` argument
type-checks but its render is a recorded follow-up.

`renderToString(e)` serializes a tree to HTML, purely and synchronously:

<!-- example: render_nested -->

**Every call spells `attrs:`, inner ones included.** The declared default
(`attrs: Array<#(string, string)> = []`) is part of every builder's signature,
but the compiler does not apply a declared parameter default at the call site
today, so omitting the argument is an arity error rather than an empty list.

## The element surface (`elements.bp`)

`element.bp` is frozen at eight constructors. `elements.bp` carries the rest of
the tag set in exactly the same shape, so a reader cannot tell from a call site
which of the two a tag came from:

```text
pub fn <tag>(children: Children, attrs: Array<#(string, string)> = []) -> Element
```

Children positional, `attrs:` labeled. The shape is not a free choice: the
`html """…"""` DSL writes `tag([kids], attrs: [pairs])`, so a constructor of any
other arity is unreachable from the markup front-end.

Two builders and two predicates:

| Function | What it is |
|---|---|
| `el(tag: string, children: Children, attrs: Array<#(string, string)>) -> Element` | The single place an ordinary element is built — and the **escape hatch** for a tag the surface does not name: `el("figure", kids, attrs: [])` |
| `voidEl(tag: string, attrs: Array<#(string, string)>) -> Element` | The same, for an element that cannot have children: it stores none |
| `isVoidTag(tag: string) -> bool` | The HTML spec's void-element list — `area`, `base`, `br`, `col`, `embed`, `hr`, `img`, `input`, `link`, `meta`, `param`, `source`, `track`, `wbr`. Written once here so a void-aware renderer consults it instead of restating it |
| `isRawTextTag(tag: string) -> bool` | `script` and `style` — the two elements whose text content is raw text and must **not** be HTML-escaped. `title` and `textarea` are *escapable* raw text, where escaping is correct, and are deliberately absent |

### The tags

| Group | Constructors |
|---|---|
| in `element.bp` (frozen) | `text`, `fragment`, `div`, `span`, `p`, `h1`, `ul`, `li` |
| sectioning and flow | `a`, `nav`, `section`, `article`, `header`, `footer`, `main`, `aside` |
| headings and text-level | `h2`, `h3`, `h4`, `h5`, `h6`, `label`, `timeTag` |
| forms | `form`, `button`, `select`, `option`, `textarea` |
| tables | `table`, `thead`, `tbody`, `tr`, `th`, `td` |
| document | `htmlTag`, `head`, `body`, `title`, `script`, `style` |
| **void** | `input`, `img`, `meta`, `link`, `br`, `hr` |

Anything else is `el("<tag>", children, attrs: [])`, or `voidEl("<tag>",
attrs: [])` when it cannot have children.

A void constructor keeps the same two-parameter shape and **drops** the
children it was handed — `input([text("x", attrs: [])], attrs: []).children` is
empty. The one-parameter `input(attrs:)` that would make children an arity
error was rejected: it is a second convention, and it is unreachable from the
`html """…"""` DSL's call shape.

### Three names that could not be the obvious one

| Tag | Constructor | Why |
|---|---|---|
| `<html>` | `htmlTag` | `html` is already the `html """…"""` template fn (member `rakun-bpp`), and a file importing the DSL beside the tags would bind two `html`s — a collision. The DSL keeps the name |
| `<time>` | `timeTag` | `time` was a std module when the tag was named (std's clock is `io.clock` since decision 106), and a consumer importing it in the same file would have collided |
| `<main>` | `main` | Shipped under its own name, because the consuming fronts import it that way |

**The `main` caveat.** A module that declares the program entry point `fn main()`
must not also `import {main} from "rakun-bpp"` in that same module. The remedy is
`el("main", children, attrs: [])`. Import aliasing is *not* a remedy: `import
{main as mainTag} from "rakun-bpp"` parses, but nothing outside the parser reads
the alias for a package import, so the binding still lands under `main`.

**Attribute values are stored verbatim.** A constructor never escapes: an `href`
of `/a&b` is kept as `/a&b`. Escaping happens once, at render, in the renderer
that emits HTML; doing it in the constructor as well would double-escape the
moment both layers are present, and a constructor cannot know whether its output
is bound for HTML, for a payload envelope, or for a test.

**`renderToString` is not void-aware.** It is `element.bp`'s in-repo test
renderer and writes a closing tag unconditionally, so
`renderToString(el("br", [], attrs: []))` answers `<br></br>`. That is why the
void set is *exported* rather than applied here: the renderer that ships reads
`isVoidTag`.

**A void element cannot be authored inside `html """…"""`.** The DSL lowers a
self-closing tag to a one-positional-argument call and flushes it after the
token loop rather than at its position, so `<div><img/></div>` renders
`<div></div><img></img>` — the image lands after its parent. Build void
elements with the constructor and interpolate the result. `<html>` in markup
is doubly unavailable: the tag would resolve to the DSL's own `html`.

## The `html` DSL — shipped (`html.bp`)

`html` captures markup **unevaluated** (`@Expr<string>` — the `"""…"""`
triple-quoted literal) and expands it, at compile time, into the `Element` builder
pipeline — at zero runtime cost. Its body is a real markup front-end (a lexer →
token stream → stack parser, the sibling of erika's `erika "…"` SQL form), so it
returns `@ExprCustom<Element>`: the executable builder code PLUS a generic
`CustomNode` reference tree the language server reads to highlight and navigate
the markup (tags, attributes, text), with each `<div>` tied to the builder it
resolves to. `val page = html """…"""` compiles straight to the builder calls;
`html` never reaches codegen.

<!-- example: html_dsl_hole -->

The expansion is:

- a lowercase `<tag>` → a bare `tag([...])` call resolved in **the caller's
  scope** (the expr-template `lookup` model), so the caller must `import` the
  builders the markup names (`div`/`p`/`li`/…); an unknown tag surfaces as an
  unbound diagnostic at the call site, pointing inside the template;
- a text run → a `text("…")` leaf (whitespace-only runs between tags are dropped,
  so the markup can be indented);
- each `${expr}` → the caller's already-typed expression, spliced as a
  `text(<expr>)` child (`html """<li>item ${n.toString()}</li>"""` →
  `li([text("item "), text(n.toString())])`).

**A tag from `elements.bp` is resolved the same way** — there is no wildcard
import and no implicit prelude, so the consumer names every tag the markup
uses:

<!-- example: html_dsl_prelude -->

(`bracketPair` is named because a `[attr]={expr}` hole lowers to a call to it.)
A tag that is not imported is an unbound-name diagnostic at the call site,
which names the tag — the one case where the surface being a plain set of
functions is an advantage.

A single root tag is returned bare; multiple top-level siblings wrap in
`fragment([...])` (which then must be imported too). Attributes (`<div
class="card">`) are parsed and surface in the reference tree for tooling, but —
as before — do not change the built `Element` (the builders take only
`Children`). A mismatched, unexpected, or unclosed tag is a `q.failAt`
diagnostic pinned to the offending tag inside the template (e.g. `html
"""<div><p>hi</div>"""` → *mismatched closing tag `</div>`, expected `</p>`*),
not a whole-template error. Bare `html`/`div`/… are reached unqualified after
`import … from "rakun-bpp"` / `from "rakun-bpp"` via the generic
loader-bare binding. Capitalized
`<Component/>` markup lookup is a **future layer** — today a component is an
ordinary `fn(...) -> Element` (its body may itself author `html """…"""`) reused
by a plain call. See `examples/jhonstart-markup`.

## The router (`router.bp`) — compiled

`router.bp` is a real module since front 26 of 1.0.10-beta; `router.d.bp` is
gone. What a component asks for is a **route snapshot**: a five-field record
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

<!-- example: router_state -->

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

### `pairValue` — the package's one pair-list decoder

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

### The pair codec is std's `encoding` (decision 116 rule 4)

The two pair-shaped snapshot values (`m`, `q`), the request's four lists and an
island's props are decoded with std's `encoding.formParse` and written with
`encoding.formStringify` — the percent-aware form codec rakun uses on the
server. `q=a%20b` reads back as `a b` on both rows, `encoding.formParse("")` is
`[]` (never `[#("", "")]`), a field with no `=` is a name with an empty value,
and `formStringify` writes no leading `?`. The package carries no pair codec of
its own.

### The snapshot, the five cells and `fill`

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

### The six hooks

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

<!-- example: router_hooks -->

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

### The navigation verbs

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

### The envelope's navigation signal, and the route a URL is

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

### `clientApp` — a client-only app (`client_app.bp`)

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

## Server components (`server.bp`) — compiled

Promoted from `server.d.bp` (front 28). The declaration file listed three
blockers; all three are answered rather than carried. The async data layer is
**not** gated any more — `fn … -> @Task<T>` with a statement-level
`await` compiles and RUNS on both rows, `test` blocks included — `request()`
keeps a host half and now ships it, and the `Http` phantom `@Context` base and
the `Request` behavior are **gone** (see `AGENTS.md` § *The `Http` base, and why
it is gone*).

### `RequestData` — the request as a record

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

<!-- example: request_data -->

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

### The six cells, and where they point

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

### The server-component convention

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

<!-- example: server_component_catch -->

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

### The loader convention, and why `@Task` being eager changes it

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

<!-- example: server_component_sequential -->

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

### Escaping is not this file's

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

## Client navigation (`link.bp`, `reconcile.bp`) — compiled

Next.js splits `<Link>` into a **render-time** half and a **runtime** half. The
render-time half emits an anchor with the props encoded on it; the runtime half,
in the browser, intercepts the click, prefetches on viewport entry and performs
the transition. rakun-bpp keeps that split, and it is what lets a client front
render correctly during the server pass.

**The render-time half is what ships.** It reaches no host cell, so `Link`
renders identically on commonJS and on erlang, and every assertion in
`test/link_test.bp` and `test/reconcile_test.bp` RUNS on both rows. It is its
own member, `rakun-bpp` — a consumer writes
`import {Link, linkProps} from "rakun-bpp";` beside the builders
`from "rakun-bpp"`, and the core does not depend on it.

### The props are a record, and why

The props are one record and `linkProps(href)` fills Next's documented
defaults: the anchor reads its options from one value. Overriding one is a
`with*` helper that returns a **new** record (a record is immutable), written
with the update form `LinkProps(..p, prefetch: prefetch)`; a consumer that
changes several at once writes the update form itself.

| Function | Shape |
|---|---|
| `LinkProps(href, prefetch, replace, scroll, target, className)` | the six props, a plain record |
| `linkProps(href)` | Next's defaults: `prefetch` true, `replace` false, `scroll` true, no `target`, no `className` |
| `withPrefetch` · `withReplace` · `withScroll` · `withTarget` · `withClass` | `(p, value) -> LinkProps` — each changes one field and copies the other five |

<!-- example: link_props -->

### The anchor

`Link(props: LinkProps, children: Children) -> Element`. The props
travel to the browser as `data-` attributes **on the anchor**: there is no
second channel and no registry the server has to serialize. An attribute is
emitted only when it **differs** from the default, so a page with two hundred
links does not carry five redundant pairs on each of them.

| Prop | Attribute | Emitted when |
|---|---|---|
| `href` | `href="…"` | always |
| — | `data-jh-l="1"` | always — the marker the runtime queries for |
| `prefetch` | `data-jh-prefetch="0"` | only when `false` |
| `replace` | `data-jh-replace="1"` | only when `true` |
| `scroll` | `data-jh-scroll="0"` | only when `false` |
| `target` | `target="…"` | only when non-empty |
| `className` | `class="…"` | only when non-empty |

```text
renderToString(Link(linkProps("/about"), [text("About", attrs: [])]))
  == "<a href=\"/about\" data-jh-l=\"1\">About</a>"
```

`data-jh-` is the milestone's marker family; this front owns the link markers
inside it and adds no other vocabulary.

### The prefetch decision

`prefetchMode(kind, hasLoading, requested) -> string` is Next's documented rule,
as a pure function so that it is testable without a browser. Both inputs come
from **front 60**'s route-kind table; rakun-bpp computes neither.

| Route kind | `loading` boundary | Mode |
|---|---|---|
| `"static"` | — | `"full"` |
| `"dynamic"` | yes | `"partial"` |
| `"dynamic"` | no | `"skip"` |
| any | `prefetch: false` | `"skip"` |

An unknown kind is not static, so it falls through to the boundary question —
the conservative answer, which is the one a missing table should produce.

### Layout keys and the remount decision

A client transition must not remount a layout the two routes share, or the
sidebar's scroll position and every client component's state inside it are lost.
A layout is keyed by its **segment path** — never by its position in the tree.

| Function | Shape |
|---|---|
| `layoutKey(segments, depth)` | `"/" + segments.take(depth).join("/")`; root layout is `"/"`; a depth past the end is the whole path |
| `layoutKeys(segments)` | `layoutKey` at every depth, root-first and root included: `["docs","api"]` → `["/", "/docs", "/docs/api"]` |
| `sharedDepth(current, target)` | the length of the common prefix: `[0, keep)` stays mounted, `[keep, n]` is replaced |

`segments` is front 26's `RouterState.segments()`, derived from the matched
pattern, so the key a client transition computes and the key the server rendered
under are the same string. `sharedDepth` is never `0` — both lists start with
`"/"` — which is the same statement as "the root layout is never remounted".

### The in-flight status

`LinkStatus(pending, href)` is what a link renders a spinner from while its own
navigation is in flight, and `linkStatusOf(href)` is the whole derivation from
the href the browser half reports (`""` when idle).

### What is NOT shipped, and what it needs

The browser half is **not** written, and it is not stubbed either. Four cells
and one hook are missing, all of them blocked on fronts that have not started:

| Missing | Needs |
|---|---|
| `__jhLinkMount()` — delegated click interception + an intersection observer over `[data-jh-l]` | front 68's generated client bundle (the module the cell binds to), which calls it once after hydrating the islands |
| `__jhLinkPrefetch(href, mode)` — warms the client route cache | the same bundle |
| `__jhLinkStatus() -> string` and `linkStatus() -> @Component<LinkStatus>` | the same bundle. The hook is then `return linkStatusOf(__jhLinkStatus());` |
| `__jhLinkRouteKind(href) -> string` | **front 60**'s route-kind table, emitted into that bundle |
| `reconcile(current, target)` — the transition driver | front 68's DOM primitives (mount/unmount), plus front 60's flag for whether the target payload had to be fetched |

Two measurements make stubbing them the wrong move rather than a shortcut:

1. A **called** node-only cell reds the **erlang** build at its call site —
   ``error: `__cellStatus` has no `#[@External.<Target>(…)]` for the erlang
   backend`` — and this module is compiled on both rows of the core member, so
   a `linkStatus()` wrapper would take every landed assertion off the erlang
   row. It is the mirror of the erlang-only → commonJS measurement `router.bp`
   and `server.bp` both carry.
2. A **declared and never called** node-only cell is fine (that is why
   `client_runtime.bp`'s `clientRender` does not red erlang) — but the module
   it names, `rakun-bpp/client-runtime`, does not exist, so the declaration
   would emit a `require` of a file nobody writes. A host stub returning an
   answer no one can check is exactly the shape `router.d.bp`'s one-line `Link`
   was, and the reason it never became real.

## The client boundary (`client.bp`) — compiled

Next.js `'use client'` does two things: it marks a module as the boundary, and it
makes everything imported from that module part of the client bundle. botopink
has no directive syntax and the milestone forbids compiler changes, so rakun-bpp
splits those two into the two places they belong: **`#[client]` marks the
component** (here), and **front 68 walks the module graph** (not here).

> **Read this first.** `#[client]` is a convention with four comptime refusals
> around it. **Front 29 defines the boundary; front 68 enforces it at build
> time.** 29 without 68 is a convention nobody walks — a secret read on the
> server still reaches the browser today if someone writes it into an island's
> props, and nothing in this package notices. § *What is checked today* below
> says exactly which line is which.

### `#[client]` — the marker

<!-- example: client_marker -->

It is an ordinary `@Decl`-first comptime function. It records **comptime
meta** — `decl.setMeta("component", "LikeButton")`, read as
`@typeInfo(LikeButton).meta.client.component` — and checks placement.

The marker is a compile-time constant and **not** a call into a runtime
registry, deliberately: a call into a Node-only cell would make every
`#[client]` component fail to link during the erlang server render — the exact
case the boundary exists to support. Meta is the same on every target and
carries the same information; front 68 reads the set of client components with
`@TypeInfo.all(with: client)`.

`#[client]` is a decorator and the `@Component<Element>` return is
the effect (decisions 118/128), so the two coexist on one component. A **server**
component that only loads data is `fn … -> @Task<Element>` and cannot be marked
client: its reflected `returnType` is `"@Task<Element>"`, which the second check
below rejects.

Applying it requires importing it — `import { client, clientProps } from
"rakun-bpp";`. The gate is `botopink test`.

### `#[clientProps]` — the serializable whitelist

The rule that actually causes production incidents is that props crossing the
boundary must be serializable. It is checked on the **record**, not on the
component, because `@Decl` exposes `fields`/`variants`/`methods`/`returnType`
and **does not expose a function's parameters** — so `#[client]` alone can check
nothing about props. That one omission is why the marker is split in two.

<!-- example: client_props_whitelist -->

The whitelist is **closed**: `string`, `i32`, `f64`, `bool`. Anything else is
refused rather than guessed at, with a message located at the declaration.
`Element` is not on it — a client component receives server-rendered children as
*children*, never as a prop.

**It is four names and not the six the front specified.** `string[]` and
`i32[]` were left out while `Field.typeName` erased an array's element type;
reflection now spells every type as the source writes it, and admitting the two
array spellings is front 29's to do. Until then an array-valued prop is spelled
as an encoded `string`.

### The island — and the one place its marker is spelled

During the server render a client component contributes an **island**. The
element carries the id and nothing else; the component name and the encoded
props live in front 23's payload, in the `i` array as `[id, component, props]`,
which is how the client finds the island without parsing attributes off the DOM
— and what makes the boundary auditable: every crossing value is in one place,
in render order, and front 68 can walk it.

| Function | Shape |
|---|---|
| `islandId(ordinal)` | `0` → `"i0"` — what an ordinal is written as |
| `islandAttrOf(id)` | `#("data-jh-i", id)` — **the only occurrence of the attribute name in this tree** |
| `islandAttr(ordinal)` | `0` → `#("data-jh-i", "i0")` — decision 77's export |
| `Island(id, component, props)` | one island; `props` is `Array<#(string, string)>` |
| `clientMount(island, children)` | the placeholder: `<div data-jh-i="i0">…children…</div>` |
| `islandEntry(island)` | the payload row `#(id, component, "k=v&k=v")` |
| `propsOf(raw)` | the inverse decode; `propsOf("")` is `[]` |

```text
renderToString(clientMount(Island(id: "i0", component: "Counter",
                                  props: [#("start", "3")]), []))
  == "<div data-jh-i=\"i0\"></div>"

islandEntry(Island(id: "i0", component: "Counter", props: [#("start", "3")]))
  == #("i0", "Counter", "start=3")
```

**Decision 77 — one definition, passed in, never two that must agree.** Front 23
assigns the ordinals in render order and fills `RenderHooks.islandAttr` from
`islandAttr` rather than spelling the pair a second time; front 68's generated
entry imports the same function for the selector it walks. It must pass a
**lambda** — `islandAttr: { n -> islandAttr(n) }`, never the bare name — because
a bare function name used as a value lowers to an unbound erlang variable, and
the field must then be read into a local before it is called (`val f =
hooks.islandAttr; f(0)`).

The encoder is std's `encoding.formStringify` (decision 116 rule 4), so a prop
value containing `&`, `=` or a space round-trips; `propsOf` decodes with
`encoding.formParse`. Nothing about the payload is escaped or built here; front
30's render collects the rows and escapes the script.

### The hole — `serverSlot`

A client component may wrap server-rendered children: the Context Provider
pattern puts a `'use client'` provider in the root layout with the entire server
tree inside it. The provider is client code; its children are not.

So the payload has a **hole**: inside `data-jh-i`, the subtree is server markup
the client must adopt as-is and must not re-render — re-rendering it would need
the server's data and the server's secrets. rakun-bpp marks the hole explicitly.

```text
renderToString(serverSlot([])) == "<div data-jh-s=\"1\"></div>"
```

Three rules follow, and **front 68** enforces all three:

1. a `data-jh-s` subtree is adopted by the client reconciler, never
   reconstructed;
2. a server component may be a *child* of a client component and never a *prop*
   of one — which is why `Element` is off the whitelist;
3. a client component may not read request scope: `request()`, `cookies()` and
   `headers()` are `server.bp`'s, and reaching them from a `#[client]` module is
   a build failure, not a runtime one.

### `serverOnly` — the poison pill

```text
pub fn serverOnly() -> i32
```

`import 'server-only'` upstream is a module that exists only to fail the build
when it lands in the client graph. This is the same trick in botopink's
vocabulary: a module that touches the server imports `serverOnly`, and front 68
fails the build when a module reachable from a `#[client]` component imports it.
**The returned value is meaningless and is never read** — its presence in a
module's import list is the whole signal.

### What is checked today, and what is not

Enforced **today**, at comptime, as a refusal with no flag that turns it off
(decision 67 — a boundary that warns is a boundary that is ignored). Each is
located at the annotation; measured against compiler `2e6bb4ac`:

| Refusal | Message |
|---|---|
| `#[client]` on anything but a `fn` | `#[client] must annotate a function` |
| `#[client]` on a fn not returning `Element` (a data-loading server component is `"Task"`) | `#[client] must annotate a component returning Element` |
| `#[clientProps]` on an enum-shaped `type` | `#[clientProps] must annotate a record, not an enum` |
| a field outside the four-scalar whitelist | ``a client prop must be serializable; 'e' is Element`` |

**Not** enforced by anything in this package:

- that a `#[client]` component's parameter record carries `#[clientProps]` at
  all — `@Decl` has no parameters, so a client component declared with a bare
  `Element` parameter is accepted;
- that no module reachable from a `#[client]` component imports `serverOnly`, or
  `request`/`cookies`/`headers`;
- that the props written into the payload's `i` row are the ones the
  `#[clientProps]` record declares — `islandEntry` encodes what it is handed.

All three are module-**graph** predicates and there is no graph here.

### The front-68 contract

| Front 68 input | Produced by |
|---|---|
| the set of client component names | `@TypeInfo.all(with: client)` — the meta `#[client]` records |
| the island rows | `islandEntry` per island, collected into the payload's `i` key by front 23 |
| the island selector | `islandAttr(ordinal)` — decision 77, the only spelling of the pair |
| the client module graph | the transitive imports of every module declaring one |
| the poison-pill predicate | a module in that graph importing `serverOnly` |
| the request-scope predicate | a module in that graph importing `request`/`cookies`/`headers` from `server.bp` |

### The hydrate point and the starter table

| Surface | What it does |
|---|---|
| `hydrate()` | walks every `[data-jh-i]`, finds that island's `i` row in the payload and starts the starter registered for its component, handing it the encoded props and `commit(html)`; calls the loader registered for the payload's matched pattern `r` once and runs again when it resolves; idempotent; mounts no link and no form |
| `registerStarter(name, start: fn(raw: string, commit: fn(html: string) -> i32) -> i32)` | the starter for one client component; a second one for the same name fails, naming it |
| `registerRouteStarters(pattern, load: fn() -> @Task<i32>)` | the loader of one route's chunk, which registers that route's starters — the bundle splits by route; one loader per pattern |
| `registeredStarters()` / `registeredRouteStarters()` | the names in the table, in registration order |
| `propsFor(name)` | `propsOf` over the payload's first `i` row for `name` |

The table is `globals.starters` (`__bp3`), the registry's fourth global, so
rakun-ssr front 68's generated entry — which calls the two `register*` functions,
then `hydrate()`, then front 27's `linkMount()` and front 67's `formMount()` —
writes no `__` name. Every cell is dual-target; on the BEAM registration reads
back the same and nothing is ever started. The "may not" rules above are front
68's walk over the client module graph.

## Render and streaming (`render.bp`, `streaming.bp`, `suspense.bp`, `plugin.bp`, `globals.bp`, `routes.bp`) — compiled

Front 30. rakun-bpp writes the HTML (decision 113): the escaping walker, the
document, the payload, the streamed fills and the navigation-signal
translation are here, and rakun / rakun-ssr hand values in.

### The walker

`renderNode(e)` is what every path renders through — never `renderToString`:
`#text` through std's `escape.html`, every attribute value through
`escape.attribute`, a void tag (front 94's `isVoidTag`) with no closing tag,
`script` / `style` (front 94's `isRawTextTag`) verbatim — a body holding
`</script` / `</style` in any case **fails the render**, never escaped — and
`raw(html)`, the one element written verbatim. `shellHtml(page)` is the page
with every boundary showing its fallback.

### Boundaries and fills

```text
pub type Boundary(id: string, fallback: Element, child: fn() -> @Component<Element>)
pub fn Suspense(b: Boundary) -> Element      // <div data-jh-h="h1">fallback</div>
pub fn holeId(index: i32) -> string          // "h1"
pub fn resolve(b: Boundary) -> @Task<Chunk>  // awaits the child once
pub fn fillHtml(c: Chunk, css: string) -> string
//   <template data-jh-f="h1">css…markup…</template><script>__bp1("h1")</script>
```

<!-- example: suspense_boundary -->

The child is an **unstarted thunk**: `@Task` is eager on erlang, so a started
Task would already have run. `Suspense` registers the boundary with the render
(an `Element` has nowhere to carry the thunk). `renderStream` hands each
boundary's thunk to its own process and writes the fills in **completion**
order as they report; `render` resolves them all first and writes one
document. On erlang the render's request and route are re-entered in each
boundary's process, and the plugins' `chunk(id)` runs there too, so a
per-process stylesheet sees what the boundary registered.

### `compose`, the UI conventions and `UiSegment`

`compose(chain, route, page)` wraps the page per segment, root-first:
`layout > template > error > loading > not-found > page`. Layouts **run
first** (each with a placeholder child, substituted afterwards), so a layout's
`redirect` means the page never runs. Each layout gets its `selected` depth
through the route snapshot; a template wrapper carries
`data-jh-t="<pattern>#<n>"`, fresh per render; `error` catches below it,
`loading` makes everything below it a streamed boundary, `not-found` wraps
below it in `data-jh-n` and is the tree a not-found signal renders.

`UiSegment` is one segment's conventions (`segment(pattern)` +
`withLayout`/`withTemplate`/`withError`/`withLoading`/`withNotFound`, or
`segmentFor(pattern)` from the registry). It is not `Segment`: that name is
the library `routing`'s, and a consumer's flat `import {Segment} from
"rakun-bpp"` would be ambiguous.

| File in `app/` | Marker | Signature it accepts |
|---|---|---|
| `layout.bp` | `#[layout(seg)]` | `fn(props: LayoutProps) -> @Component<Element>` |
| `template.bp` | `#[template(seg)]` | `fn(props: LayoutProps) -> @Component<Element>` |
| `page.bp` | `#[page(seg)]` | `fn(route: PageContext) -> @Component<Element>` (+ `<name>Params(route)`) |
| `default.bp` | `#[defaultView(seg)]` | `fn(props: LayoutProps) -> Element` |

`#[page]`, `#[layout]` and `#[template]` refuse any other return, naming the
function and the form it needs. A marker registers nothing itself: it records
its segment as meta (`seg`), and the program's entry point registers every
marked function once, from the program's catalogue:

```text
val __jhRoutes = jhRegisterRoutes(
    @TypeInfo.all(with: page),
    @TypeInfo.all(with: layout),
    @TypeInfo.all(with: template),
    @TypeInfo.all(with: defaultView),
);
```

Layouts register first, then templates, pages and default views, each in the
catalogue's order (module path, then declaration order). The module holding
that line is imported by nobody — rakun-ssr's generated `onze_main.bp`, or a test
file. The application site imports what `#[page]`'s accessor emits
(`PageContext`, `ctxParam`, `ctxRest`). `uiTable()` answers the registry as
contract-1 lines; rakun-ssr copies it into rakun's table.

### The response and the two entries

```text
pub type Response(status: fn(code: i32) -> void, header: fn(name: string, value: string) -> void,
                  write: fn(chunk: string) -> @Task<void>, close: fn() -> @Task<void>)
pub type PageInput(build, pathname, pattern, params, query, table, actions,
                   chain: Array<UiSegment>, page: fn() -> @Component<Element>,
                   metadata: Array<Metadata>, viewports: Array<Viewport>)
pub fn app(plugins: Array<RenderPlugin>, allowedRedirects: string[] = [], lang: string = "en") -> App
site.render(input, req, res) -> @Task<@Result<void, string>>
site.renderStream(input, req, res) -> @Task<@Result<void, string>>
```

`lang` is the document's `<html lang>`: letters, digits and `-`, starting with
a letter (`isLangTag`); `app` refuses anything else, naming it.

The render enters `req` (front 28) and leaves it, writes `status(200)` and the
content type before its first `write`, and calls `close()` exactly once on
every path; `status` / `header` after the first write fail the render. It
answers `Ok` for a closed response — normal or signalled — and `Error(message)`
for a failed render. `metadata` / `viewports` are the segments' resolved
exports, merged root-first (front 32).

| A signal raised | The render writes |
|---|---|
| `redirect(to)` before the first chunk | `status(307)`, `header("location", to)`, `close()` |
| `notFound()` before the first chunk | `status(404)`, a document whose body is the nearest not-found boundary |
| either, after the first chunk | `<template data-jh-g="redirect" data-jh-to="…">` / `<template data-jh-g="not-found">…` + `<script>__bp2()</script>` as the last chunk; status stays 200 |

A redirect target is checked the same way everywhere: a relative target must be
matched by `routing`'s `matchPath` in `PageInput.table`, an absolute one listed
in `app(allowedRedirects: […])` (empty by default); anything else fails the
render with no status, no `location` and no markup.

### The payload and the globals

One `<script>window.__bp0 = {…}</script>`, last in `<body>` before
`RenderHooks.bodyExtra`: keys `v` (1), `b`, `p`, `r`, `m`, `q`, `t`, `i`, `a`,
`h`, `d`, then each plugin's key. Written with std's `json.quote` /
`json.array` / `json.object` and passed through `escape.scriptJson`, so
`</script` cannot appear in it. Island ids are `i0`, `i1`, … in render order
(`mountIsland`, through front 29's `islandEntry`).

The four browser globals are aliases from `globals.bp`'s registry —
`globals.payload == "__bp0"`, `.fill == "__bp1"`, `.signal == "__bp2"`,
`.starters == "__bp3"` (the island starter table, front 29), the fields of one
module-level `pub val globals` — and no other file spells them. `readPayload(name)` decodes the payload text with
std's `json.decode`; `registerFill` / `registerSignal` install `render.mjs`'s
fill and signal functions (called only by rakun-ssr front 68's entry).

### `RenderPlugin`

```text
pub type RenderPlugin(name: string, head: fn() -> @Task<string>, chunk: fn(holeId: string) -> @Task<string>,
                      close: fn() -> @Task<@Result<void, string>>, payload: fn() -> @Task<Array<#(string, Json)>>)
```

A record of async functions (an array of two different behavior implementors
does not type). `head` once, into `<head>`; `chunk(id)` per streamed boundary,
first inside its fill; `close` at the end — an `Error` fails the render;
`payload` once, last — a render key or a key two plugins give fails the render,
naming them. The `rakun-stylesheet` member is the one plugin in this workspace.

## Forms (`rakun-bpp`) — compiled

Front 67, `import {…} from "rakun-bpp"`. A form is bound to front 24's
action id (a string — this front echoes it and never constructs one) and its
markup is contract 3's exactly, so it submits before the bundle arrives:

<!-- example: form_action -->

| Function | What |
|---|---|
| `formAction(id, pathname, actionField)` · `formAttrs` · `hiddenActionField` · `actionForm` | the binding and contract 3's markup; an id that is not `actions`' `isActionId` (`a_` + 24 lowercase hex) is refused |
| `submitForm(binding, fields)` · `invokeAction(id, args, actionHeader)` | the POST / the JSON-RPC call; the answer read by `actions`' `parseActionState`; a redirect in `n` is the router's `push`; `ok: false` is DATA, returned as the state |
| `formMount(actionHeader)` | one delegated submit listener over `[data-jh-a]`, called once by rakun-ssr front 68's entry |
| `actionState(id, initial)` | the hook — `#(state, binding, pending)`, read positionally; server pass: `initial`, `false` |
| `formStatus()` · `formStatusOf(id)` | idle on the server pass and outside any form, never an error |
| `optimistic(base, apply)` · `applyOptimistic(base, actions, apply)` | server pass `#(base, no-op)`; the fold is pure |
| `searchFormProps` · `searchFormAttrs` · `searchHref` · `prefetchSearch` | § 25's GET `<Form>`: `method="get"`, `data-jh-sf="1"`, never `data-jh-a` |
| `setWireNames(actionField, actionHeader)` | rakun-ssr installs the two wire names once; this member spells neither |

`formStatus` and `optimistic` are specified from upstream React
(<https://react.dev/reference/react-dom/hooks/useFormStatus>,
<https://react.dev/reference/react/useOptimistic>), not from `NEXTJS-DOCS.md`,
which does not carry them.

## Error boundaries (`error_boundary.bp`) — compiled

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

<!-- example: error_boundary -->

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

## Metadata (`metadata.bp`) — compiled

Front 32. Metadata is the one part of a page **composed** down the layout chain
rather than nested: each segment declares a `Metadata`, and front 30's render
merges them root-first and splices `renderHead` into `<head>`.

```text
pub type Metadata(title, titleTemplate, description, openGraph: OpenGraph, twitter: TwitterCard, icons: Icons)
pub type OpenGraph(title, description, url, ogType, siteName, images: string[])
pub type TwitterCard(card, title, description, images: string[])
pub type Icons(icon, apple)
pub type Viewport(width, initialScale, themeColor)

pub fn emptyMetadata() -> Metadata        // also emptyOpenGraph / emptyTwitter / emptyIcons / emptyViewport
pub fn mergeMetadata(parent, child) -> Metadata
pub fn mergeViewport(parent, child) -> Viewport
pub fn renderHead(m: Metadata) -> string  // one tag per line, fixed order, escaped
pub fn renderViewport(v: Viewport) -> string
pub fn pick / pickList / applyTemplate
```

<!-- example: metadata_merge -->

No field is optional: an absent string is `""`, an absent list `[]`, and a
`""` field emits no tag. Every value goes through std's `escape.html` (the
`<title>` text) or `escape.attribute` (every `content` / `href`).

**The export contract front 30 resolves against:**

| Segment export | Kind | Front 30 does |
|---|---|---|
| `metadata()` | static — a zero-argument `pub fn`, not a `pub val` | calls it, merges onto the parent's |
| `generateMetadata(params, parent)` | `-> @Task<Metadata>` | awaits it, merges onto the parent's |
| both present | error | fails the build with a located message |
| `viewport()` / `generateViewport(params)` | as above | merged independently of `Metadata` |

**The merge rule:**

| Field kind | Rule | Example |
|---|---|---|
| string | a non-empty child replaces; an empty child inherits | child `title: ""` keeps the parent's title |
| array | a non-empty child replaces **wholesale**; an empty child inherits | one `og:image` on the page replaces the layout's three |
| nested record | merged field by field, by the same two rules | `openGraph.title` from the page, `openGraph.siteName` from the layout |
| `titleTemplate` | applied by the parent to the **child's** title, once; the result carries the child's template | `"%s \| botopink"` + `"Hello"` → `"Hello \| botopink"` |

The head's order: `<title>`, `description`, `og:title`, `og:description`,
`og:url`, `og:type`, `og:site_name`, one `og:image` per image, `twitter:card`,
`twitter:title`, `twitter:description`, one `twitter:image` per image, the
`icon` link, the `apple-touch-icon` link. `sitemap`, `robots`, `manifest` and
`opengraph-image` are file routes — rakun front 66's; the image and icon paths
reach `Metadata` as data rakun-ssr copies in, and their convention is written in
front 66's README.

## App layer (Next-style) — declared, host-bound

- `Link` is no longer declared: see *Client navigation* above. `link.bp` and
  `reconcile.bp` are compiled and pure; what is still missing is the **browser
  half** — front 68's generated bundle and front 60's route-kind table.
  The router itself is no longer declared either: see *The router* above.
- The server context is no longer declared either: see *Server components*
  above. `server.bp` is compiled, with both host halves shipped.
- File routing (`app/`, `page.bp`, `layout.bp`, `[id]`) is a **convention** (V1),
  wired manually until a CLI/build step lands.
- `renderToString(app)` (SSR, real `.bp`) / client `mount` (host).

## V1 limits

- **Implemented now** (`element.bp` + `elements.bp` + `hooks.bp`, and `html.bp` in `rakun-bpp`, compiled +
  `test {}`-checked): the `Element` type, builders (`Children` args, list-form
  render), the element surface (`el`/`voidEl`, `isVoidTag`/`isRawTextTag` and
  thirty-eight further tag constructors), a synchronous `renderToString`, the
  `state`/`effect`/`memo`/`ref`/`reducer` hook family (real SSR bodies), the
  route snapshot and its six hooks and six navigation verbs (`router.bp`, with
  both host halves), the request record, its four accessors, `request()` and
  the server-component convention (`server.bp`, with both host halves), the
  render-time half of client navigation — `Link`, `LinkProps` and its five
  `with*` helpers, `prefetchMode`, `layoutKey`, `layoutKeys`, `sharedDepth`,
  `linkStatusOf` (`link.bp` + `reconcile.bp` in `rakun-bpp`, pure, no host cell), the client
  boundary — `#[client]`, `#[clientProps]` and the four comptime refusals
  around them, `islandId`/`islandAttrOf`/`islandAttr`, `Island`, `clientMount`,
  `islandEntry`, `propsOf`, `serverSlotAttr`/`serverSlot` and the `serverOnly`
  poison pill (`client.bp`, pure, no host cell) — and the
  `html """…"""` markup DSL
  (comptime expansion to the builder pipeline). Author trees as `div([…])` or as
  `html """…"""`.
- **Gated / declarative** (each a generic core gap, none jhonstart-specific):
  - (closed) `use request()`: `request()` is `fn … -> @Component<RequestData>` (botopink decisions 104/128), activated inside a
    `@Component<Element>` server component.
    The server surface itself is no longer gated: `server.bp` is compiled with
    both host halves shipped (see *Server components*). `Link` and the form
    controls are no longer gated on an attribute slot either: `Element` carries
    `attrs`, and `elements.bp` ships
    `form`/`input`/`button`/`label`/`select`/`textarea`; `Link` is front 27's
    `src/link.bp`, compiled and pure — see *Client navigation*;
  - the **browser half** of client navigation. `link.bp` and `reconcile.bp`
    ship the render-time half; the four `#[@External.Node]` cells
    (`__jhLinkMount`, `__jhLinkPrefetch`, `__jhLinkStatus`,
    `__jhLinkRouteKind`), the `linkStatus()` hook and the transition driver
    `reconcile(current, target)` wait on front 68's generated bundle and front
    60's route-kind table, and are not stubbed;
  - the **build-time half** of the client boundary. `client.bp` ships the
    markers, the island and the hole; the two `#[@External.Node]` cells
    (`hydrate`, `islandProps`), the `propsFor(name)` wrapper over the second,
    and every "may not" rule — no `serverOnly` in the client graph, no request
    scope in a client module, a server component as a child and never a prop —
    wait on **front 68**'s walk over the module graph and its generated bundle,
    and are not stubbed. **Today the boundary is a vocabulary with four
    comptime refusals, not a guarantee**: a secret read on the server still
    reaches the browser if it is written into an island's props;
  - parallel loading. `@Task` is eager on the erlang row, so independent
    loaders awaited in sequence cost the sum of their round trips; the
    spawn-and-gather over unstarted tasks is front 02's and rakun-bpp ships no
    second answer;
  - HTML escaping. `renderToString` escapes nothing and front 01's
    `escape.html` / `escape.attribute` do not exist yet;
  - the trailing-lambda children sugar (`div { … }`) and lone-child / `string`
    `Children` *rendering* (type-checks today; render needs normalization).
