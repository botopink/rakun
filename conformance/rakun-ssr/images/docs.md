# Images

> Package: [`rakun-ssr`](../docs.md) · index: [`../../docs.md`](../../docs.md)

`Image(props, config, publicDir)` renders an `<img>` whose URLs go through `/_onze/image`, with a
`srcset` (every configured width up to `width` with `sizes`, every width with `fill`, the 1×/2× pair
otherwise — each snapped to a configured width), the box reserved by `width`/`height` or a fill
style, and the loading policy (`priority` → eager, `fetchpriority="high"`; otherwise lazy, async
decoding). The source rules: a `/`-rooted path must stay inside `public/`; an absolute URL must match
`remotePatterns`, **empty by default**; `*.example.com` matches exactly one label; `hostname: "*"` is
refused at config load; `data:` and `file:` URLs are refused. A refused source renders nothing and
is reported, never fetched unoptimized.

**No NIF.** Pixels never enter the VM: the handler spawns one external encoder (`vips` by default,
`magick` accepted) with an argument vector under a deadline the VM keeps (`encoderTimeoutMs`, no
external `timeout` tool); a slow encoder is killed and fails one request. **A missing encoder degrades to pass-through** — the original file is served, and the
handler says optimization is off — because an encoder is an operational dependency; this is the one
place rakun-ssr degrades instead of failing. Encoded files are keyed by the hash of `src`, `w`, `q`,
`f` and the encoder version, served `public, max-age=31536000, immutable` with that hash as
`ETag`; a width outside `deviceWidths` or a quality outside 1..100 is a 400.
