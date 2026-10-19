# Decision 661 — (b), read with 504: everything in rakun-style is a component — `Styleable.toStyled(self: Self) -> Component<Styled>` stays — and being a component asks no `await` of its callers: calling a component only makes its lambda (388, 504), so `Sheet.add(self: Self, layerName: string, item: Styleable) -> Sheet` stays a plain function, keeps its chain, and stores `item.toStyled()` — a component value — in the entry; the renderer runs the stored components when the sheet is rendered.

The example builds a rakun-style sheet in a plain function. `card` and `tab4` are literals and
`badge("teal")` a call; each is a component — `Component<Styled>`, `Component<StyledProperty>` —
and calling `badge` only makes its lambda. `appSheet` chains three `add` calls with no `await` and
no `use`: each `add` stores the entry's component value (`item.toStyled()`) and answers the new
sheet, so the chain is ordinary code and `entries.length` is `3`. Nothing has run yet. `render()` is
the one component body: `main` awaits it, it runs each stored component in the render's scope, and
writes the CSS — `@layer base{…}` with the `tab-size` rule, then `@layer components{…}` with the card
and the badge, each once under its class. The program writes `Component<Styled>` where the old
`StyledView` alias stood; the alias is gone.

Proving cells: none in this repository yet; rakun-style has no `conformance/` cells, and the sheet's
cells come with front 150 s34.

[draft/main.bp](draft/main.bp)
