# Decision 300 — The theme keeps CSS's flat entry list, typed, and is declared once with `#[theme]`

The application declares its theme once: `#[theme] pub val appTheme`, built at build by `extendTheme` from the base theme and three typed changes of `rakun-style`. `entry(.Breakpoint, "md", .Rem(40.0))` moves the `md` breakpoint — a breakpoint is a length, so its value is `Rem`, `Px` or `Em`; `clear(.Breakpoint, "lg")` drops one; `entry(.Color, "brand", .Raw("#e11d48"))` adds a colour. The name inside a namespace stays CSS's string. The program prints `40rem`, `#e11d48`, `true` (the cleared `lg` is remembered as cleared, not unknown) and the untouched `40rem` of `sm`, then the count of declarations carrying `#[theme]`, found at build: `1`.

A second `#[theme]` is an error, and so is none (decision 358). A token naming a cleared or absent breakpoint is a compile error where the token list is known at build. A bare `comptime extendTheme(…);` statement registers nothing.

Cells of this repository that prove it: `rakun-stylesheet/theme/theme-api`, `rakun-stylesheet/theme/theme-brand` and `rakun-stylesheet/theme/palette-entries` show the flat entry list over the Tailwind values, through rakun-stylesheet's own `extendTheme(theme, ThemeEntry[])`, not yet the typed `entry` / `clear` changes (`06-emilia/34` step 3).

[draft/main.bp](draft/main.bp)
