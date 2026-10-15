# Social cards

> Package: [`rakun-ssr`](../docs.md) · index: [`../../docs.md`](../../docs.md)

An image route answers an `ImageResponse` — tree, size (1200×630 by default), content type
(`image/png` by default) and faces — never bytes. The card is laid out and emitted as SVG on the BEAM
in pure botopink: a closed style subset (`supportedProperties()`; an unsupported or malformed
declaration is reported and fails the route), a small flexbox (row/column, justify, align, gap,
padding, `%`/`px`, absolute children), text wrapped at spaces over front 52's metrics sidecars (a
word wider than the box overflows; `maxLines` ends with `…`), and `<text>` elements with explicit
font attributes and escaped content.

**The rasterizer decision.** `image/svg+xml` needs no tool. `image/png` goes through a **port** by
default — `resvg` or `rsvg-convert`, spawned with the SVG in a file; a crash kills that process, not
the node. A **NIF** is opt-in and not shipped: a segfault in a native rasterizer takes the whole VM
down and needs a compiled artifact per platform, which the release would then have to package.
With neither, a PNG route fails the build naming the route and the commands — nothing falls back
to SVG under a PNG content type. A card renders once: its key hashes the route, the params, the
SVG, the faces and the size, so a template change invalidates it with no version bump.
