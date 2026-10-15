# The client boundary

> Package: [`rakun-bpp`](../docs.md) · index: [`../../docs.md`](../../docs.md)

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

## `#[client]` — the marker

{client_marker/src/main.bp}

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

## `#[clientProps]` — the serializable whitelist

The rule that actually causes production incidents is that props crossing the
boundary must be serializable. It is checked on the **record**, not on the
component, because `@Decl` exposes `fields`/`variants`/`methods`/`returnType`
and **does not expose a function's parameters** — so `#[client]` alone can check
nothing about props. That one omission is why the marker is split in two.

{client_props_whitelist/src/main.bp}

The whitelist is **closed**: `string`, `i32`, `f64`, `bool`. Anything else is
refused rather than guessed at, with a message located at the declaration.
`Element` is not on it — a client component receives server-rendered children as
*children*, never as a prop.

**It is four names and not the six the front specified.** `string[]` and
`i32[]` were left out while `Field.typeName` erased an array's element type;
reflection now spells every type as the source writes it, and admitting the two
array spellings is front 29's to do. Until then an array-valued prop is spelled
as an encoded `string`.

## The island — and the one place its marker is spelled

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

## The hole — `serverSlot`

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

## `serverOnly` — the poison pill

```text
pub fn serverOnly() -> i32
```

`import 'server-only'` upstream is a module that exists only to fail the build
when it lands in the client graph. This is the same trick in botopink's
vocabulary: a module that touches the server imports `serverOnly`, and front 68
fails the build when a module reachable from a `#[client]` component imports it.
**The returned value is meaningless and is never read** — its presence in a
module's import list is the whole signal.

## What is checked today, and what is not

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

## The front-68 contract

| Front 68 input | Produced by |
|---|---|
| the set of client component names | `@TypeInfo.all(with: client)` — the meta `#[client]` records |
| the island rows | `islandEntry` per island, collected into the payload's `i` key by front 23 |
| the island selector | `islandAttr(ordinal)` — decision 77, the only spelling of the pair |
| the client module graph | the transitive imports of every module declaring one |
| the poison-pill predicate | a module in that graph importing `serverOnly` |
| the request-scope predicate | a module in that graph importing `request`/`cookies`/`headers` from `server.bp` |

## The hydrate point and the starter table

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
