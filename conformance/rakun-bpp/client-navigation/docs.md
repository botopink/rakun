# Client navigation

> Package: [`rakun-bpp`](../docs.md) · index: [`../../docs.md`](../../docs.md)

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

## The props are a record, and why

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

{link_props/src/main.bp}

## The anchor

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

## The prefetch decision

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

## Layout keys and the remount decision

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

## The in-flight status

`LinkStatus(pending, href)` is what a link renders a spinner from while its own
navigation is in flight, and `linkStatusOf(href)` is the whole derivation from
the href the browser half reports (`""` when idle).

## What is NOT shipped, and what it needs

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
