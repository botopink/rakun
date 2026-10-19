# Decision 594 — Every library runs at build on the wasm comptime runtime (434), jhonstart first; a function only Erlang or Node can run is a located error there.

The footer is rendered twice with rakun-bpp's `renderToString`. `comptime footer(2026)` renders it at build, on the wasm comptime runtime — whatever `--target` the program is built for — and splices the markup as a literal; `footer(2026)` renders it again when the program runs. The program prints `<div><p>© 2026 rakun</p></div>`, then `true`: the renderer's escaping and formatting cells have a wasm form, so build and run answer one string.

Were the render to reach a host cell with no wasm form — an Erlang-only or Node-only function, or a real effect such as the network or a database — the `comptime` line would be refused at build, located, naming the cell; it never runs on the target's VM, and an erlang build is refused as a commonJS one is.

Cells of this repository that prove it: none yet — rakun-bpp's wasm forms are `1-botopink-lang/144` B-17's and the library front's step; the renderer's cells run `renderToString` on the target only.

[draft/main.bp](draft/main.bp)
