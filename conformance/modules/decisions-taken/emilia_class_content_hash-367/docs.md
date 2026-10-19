# Decision 367 — Contract 4 follows 338: an emilia class is the layer's prefix plus `contentHash` over the class's rules, as `styled` renders them — one class rule for every component.

`cardTokens` is contract 4's shared fixture: a white background, `p-4`, bold text and a hover background. `rakun-stylesheet` (emilia's package now) computes the card's class at build, `comptime className(cardTokens(), defaultTheme())`, and the program prints `e_f51c2501`. The second line checks how that name is made and prints `true`. It is the layer's prefix `e_` followed by std's `contentHash` over the class's rules, written as `styled` renders them with the class as `\u{1}`, the same rule every `styled` component follows under its own prefix. The hash is over the rules and not over the codec's payload, which carries no hash. So the same tokens in another order are other rules: the third line prints `false`, because `rakun-style`'s reader keeps source order and the order is part of the class's identity.

Cells in this repository that prove it: `rakun-stylesheet/output/stable-hashes` (one class for one content) and `rakun-stylesheet/output/sheet-api`. The fixture's re-derivation is front 150 s52, and `className` as a value of build arrives with 369's tag decorator.

[draft/main.bp](draft/main.bp)
