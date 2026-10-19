# Decision 378 — A context always declares its default; a read answers the nearest provider above or the default; `context-unbound` goes.

`Theme` is a record, and `themeContext` is its one declared default, `comptime createContext(Theme(primary: "#e11d48", radius: 4))`, computed at build. `Swatch` reads it with `use context(Theme)` and renders the colour and the radius through rakun-bpp's `p` and `text`. Rendered at the root, with nothing provided above it, `Swatch` answers the default: `<p>#e11d48/4</p>`. `DarkPanel` provides another `Theme` with `use provide(createContext(…))` before rendering its child, so the same `Swatch` inside it answers the nearest provider: `<div><p>#111827/0</p></div>`. No read is ever unbound — the provider, else the default, on every target.

A context whose absence is a bug says so through its default (rakun-bpp's `StyledContext`, whose missing sheet panics naming the provider the render's root gives). A component may also be called at build — `comptime renderToString(…)` in a module `val` is a string constant — its contexts answering their providers within the tree or their defaults; one reaching a run-time hook is refused at the call. A `use` written directly in a decorator, a template or a `comptime` body stays refused.

Cells of this repository that prove it: none yet. `rakun-bpp/hooks/hook_noun_custom` shows `use` over a hook noun; the contexts' cells come with `08-bpp/119` (`StyledContext`) and `05-jhonstart`'s contexts.

[draft/main.bp](draft/main.bp)
