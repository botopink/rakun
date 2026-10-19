# Metadata

> Package: [`rakun-bpp`](../docs.md) · index: [`../../docs.md`](../../docs.md)

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

{metadata_merge/src/main.bp}

No field is optional: an absent string is `""`, an absent list `[]`, and a
`""` field emits no tag. Every value goes through std's `escape.html` (the
`<title>` text) or `escape.attribute` (every `content` / `href`).

**The export contract front 30 resolves against:**

| Segment export | Kind | Front 30 does |
|---|---|---|
| `metadata()` | static — a zero-argument `pub fn`, not a `pub val` | calls it, merges onto the parent's |
| `generateMetadata(params, parent)` | `-> Task<Metadata>` | awaits it, merges onto the parent's |
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
