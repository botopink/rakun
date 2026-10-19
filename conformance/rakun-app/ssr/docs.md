# Server-side rendering

> Package: [`rakun-app`](../docs.md) · index: [`../../docs.md`](../../docs.md)

This text predates the move of the render into `rakun-bpp` (`render.bp`): no
cell checks it, and several names below (`ElementView`, `withHeadExtra`,
`beginRender`, `renderAll`, `streamChunks`, `nodeView`) are not in
`modules/rakun-app/src/` today.

`from "rakun-app"` gives you the render pipeline: a URL in, an ordered list of HTML
chunks out, with every string that came from a request, a database or a file
escaped on the way.

## The element view — one adapter, written once

rakun does not know what an element is. It declares no dependency on a UI
library, so the six things a walker needs are handed to it as a record:

```text
import {ElementView, renderNode} from "rakun-app";
import {Element, isVoidTag, isRawTextTag} from "rakun-bpp";

pub fn bppView() -> ElementView<Element> {
    return ElementView(
        make: { t, v, a, c -> Element(tag: t, value: v, children: c, attrs: a) },
        tagOf: { e -> elementTag(e) },
        valueOf: { e -> elementValue(e) },
        attrsOf: { e -> elementAttrs(e) },
        childrenOf: { e -> elementChildren(e) },
        isVoid: { t -> isVoidTag(t) },
        isRawText: { t -> isRawTextTag(t) },
    );
}
```

One rule, which costs an hour if you learn it from a diagnostic instead of
from here:

- **Wrap an imported function in a lambda.** `isVoid: isVoidTag` with
  `isVoidTag` imported is `unbound variable 'isVoidTag'`; `{ t -> isVoidTag(t) }`
  is the same value and lowers on every row.

A function-valued field is called in place — `v.tagOf(e)` applies the field.

The four readers are named functions taking a typed parameter — a field read
inside a lambda loses the parameter's type on the erlang row.

An application that ships no UI library can use rakun's own `Node` through
`nodeView(isVoid, isRawText)`.

## Rendering a tree

```text
val v: ElementView<Element> = bppView();
val html = renderNode(v, tree);
```

`renderNode` escapes `&`, `<` and `>` in a text node and adds `"` and `'` in an
attribute value; it emits `<input>` with no closing tag; it emits a `script` or
`style` body verbatim, because escaping CSS or JavaScript changes the program;
and it REFUSES a `script`/`style` body containing `</script` or `</style`, in
any case, naming the tag. There is no option that turns that refusal into
escaping.

`raw(v, "<b>x</b>")` is the one escape hatch and it renders verbatim. Every use
of it is a place a reviewer must look at.

## Composing a page with its layouts

```text
val table = appTable();
if (matchPath(table, "/blog/hello")) { hit ->
    val ctx = contextOf(hit, "/blog/hello", emptyParams());
    val tree = compose(v, hit.chain, ctx, nav, page);
};
```

`hit.chain` is already the root-first layout list — do not call `layoutChain`
again for a match you already hold. `compose` wraps the page from the inside
out, so the rendered nesting is
`layout > template > error > loading > not-found > page`, and a convention your
app does not define contributes no wrapper.

A layout learns how deep it sits with `selected()` — `0` for the root layout,
`1` for the next one down. It is a call rather than a field of `LayoutProps`
because that record is the router's and carries three fields.

## The document and the payload

```text
val doc = await document(renderHead(meta), body, Payload(
    build: buildId(), pathname: "/blog/hello", pattern: "/blog/[slug]",
    params: "slug=hello", query: "page=2", table: rkAppTable(),
    islands: [], actions: [], styles: "", holes: [], dynamic: false,
    kinds: "", slots: "",
));
```

`document` writes the doctype, the head, the body inside
`<div data-onze-root="">`, and then one
`<script id="__onze" type="application/json">` carrying the payload the browser
reconnects through. Inside that block `<`, `>` and `&` are written as `\u003c`,
`\u003e` and `\u0026`, so `</script` cannot occur in it at all — which is why
a param carrying `</script><img src=x onerror=…>` produces a document with no
`<img` in it.

## `RenderHooks` — what a framework adds, without rakun knowing about it

rakun never imports a bundler or a stylesheet pipeline. Everything a full-stack
framework adds to a document arrives as a record of functions:

```text
val custom = withHeadExtra(defaultHooks(), { route -> "<link rel=\"stylesheet\" href=\"/app.css\">" });
val _ = setHooks(custom);
```

Seven fields — `headExtra`, `bodyExtra`, `islandAttr`, `openSink`,
`collectHead`, `collectChunk`, `closeSink` — each replaceable on its own, the
other six staying at their defaults. A document rendered through
`defaultHooks()` is a working page with no extra tags and no `<style>` block:
the stylesheet is the sink's, and the sink is installed by whoever boots the
app.

## Rendering a request

```text
val epoch = beginRender(random.uuidV4(), "/blog/hello", "page=2", false);
val page = await render(view, "/blog/hello", "page=2");
val cookies = endRender();          // on the failure path too
val res = toResponse(page);
```

`render` opens phase `Render`, finds the page, wraps it in its layouts, renders
with escaping, writes the document, and answers a `RenderedPage(status, headers,
chunks)` carrying `Content-Type: text/html; charset=utf-8`. A URL no page claims
answers 404 with the `not-found` boundary's markup. Read a chunk with
`chunkAt(page, i)` and the whole body with `bodyOf(page)` — not
`page.chunks.at(i)`, which loses the optional on the erlang row.

`endRender()` must run **on the failure path too**: without it, the next request
on a keep-alive connection starts inside this one's frame.

Reading the search params marks the render dynamic:

```text
val page = searchParam(route, "page");   // sets the payload's `d` to true
```

## Slow sections: thunks, never started tasks

`Task<T>` lowers eagerly on erlang, so awaiting two tasks runs them one
after the other at full latency. Concurrency comes from processes:

```text
var loaders: Array<fn() -> Task<Element>> = [];
loaders.push({ -> loadPosts() });
loaders.push({ -> loadAuthor() });
val resolved = await renderAll(loaders);   // one process per thunk, one await
```

Never hand `renderAll` an already-started `Task` — the parameter is a
function type, so it will not fit, which is the point.

## Streaming

```text
val resolved = await renderAll(bodies);
val page = streamChunks(head, shell, ids, markupAll(view, resolved), payload);
```

The shell goes out first, ending inside `<body>`; one fill chunk follows per
boundary, in the order they RESOLVED —
`<template data-onze-f="h1">…</template><script>__onzeFill("h1")</script>` —
and the tail carries the payload. Hole ids are `h1`, `h2`, … in SHELL order
whatever the clock did, and a boundary that finished before the shell was
flushed is simply not in the list: it rendered inline and gets no hole.
