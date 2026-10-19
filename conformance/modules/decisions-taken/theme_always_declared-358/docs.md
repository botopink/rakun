# Decision 358 — The theme is always declared: an application that expands a `styled` literal has exactly one `#[theme]`, and none is a compile error — no implicit default.

An application of `rakun-style` that declares no theme. `wide`, its one `styled` literal, reads the theme — `@variant md` and `--theme(--breakpoint-md)` name the theme's `md` breakpoint — and there is no implicit default for it to read, so the program is refused at compile time at that literal, the first that reads the theme, naming the fix: `#[theme] pub val appTheme = comptime baseTheme();` (or `= comptime defaultTheme();` for the whole Tailwind theme, palette included). With that line added, the theme is a `val` built at compile time and registered by `#[theme]` through `compiler.init`; the literal emits code reading the registry, and `main` prints rules holding `@media (width >= 48rem)` and `max-width:48rem`.

A second `#[theme]` is not a compile error: by decision 665 it is the registering executor's refusal at init, before `main`, since nothing reads the set of marked declarations at build.

Departure on `feat`: `rakun-style`'s template reads `baseTheme()` whatever the program declares (its `// LANGUAGE GAP` in `styled.bp`), so this program compiles and runs.
Departure on `feat`: `use wide()` of a component is refused with `use-of-non-context-fn`.

Cells of this repository that prove it: none yet. The refusal waits on `01-compiler/130` step 10 and `06-emilia/34` step 3; `examples/rakun-style/styled-example` declares a theme.

[draft/main.bp](draft/main.bp)
