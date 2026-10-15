# palette-entries

{src/main.bp}

### The colour palette

`defaultTheme()` carries `--color-black` and `--color-white` and nothing else.
The 286 numeric values are front 33's data, handed over as
`paletteEntries() -> ThemeEntry[]` and composed by the consumer:

It is a **list, not a rendered block**, and that is the point: a project that
already imports upstream's own theme leaves it out and still uses every colour
token, because a token emits `var(--color-red-500)` and whoever declares that
variable is the consumer's call. `emilia(...)` emits no `@theme` block of its
own, at any size of token list.

The values are transcribed from upstream `tailwindcss` **4.3.2**'s
`theme.css`. The reference prints exactly two of them
(`--color-red-500`, `--color-blue-500`) in the decimal-lightness spelling
`oklch(0.637 0.237 25.331)`; upstream writes the same colour as
`oklch(63.7% 0.237 25.331)`. Both are the same lightness in OKLCH; rakun-stylesheet
takes upstream's, so the emitted `@theme` block is byte-equal with the one a
project would otherwise import.
