# Decision 382 — `#[emilia(…)]`'s tokens are an expression, as every `comptime` parameter (364): `pub fn emilia(comptime decl: @Decl, comptime ..tokens: @Expr<Token[]>)`.

An application that styles a component with `rakun-stylesheet`'s decorator: `#[emilia(.Pad.All.4, .Bg.White, .Color.Black, Token.Hover([.Color.Red.600]))]` on `Card`. The markup is the ordinary token paths, each leading-dot path resolved against `Token`; what the decorator receives is the list as an expression of `Token[]` — a `comptime` variadic, as every other `comptime` parameter — and its body reads the four values from it, the hover modifier's payload included. `main` renders the card and prints the flushed document, which holds the rule the decorator registered for the card's tokens.

A token the decorator cannot use — one the declared theme lacks — is reported at that argument of the annotation, not at the decorator's own source: the variadic carries the argument's location as any `comptime` parameter does, with no exception for a decorator.

Cells of this repository that prove it: none yet. `rakun-stylesheet`'s `emilia` is today a plain function over a `Token[]` (`emilia(tokens)`, `src/emilia.bp`); the decorator comes with `06-emilia/34` step 5 box 4 and `08-bpp/119` step 4.

[draft/main.bp](draft/main.bp)
