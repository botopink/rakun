# layout-display

{src/main.bp}

### Layout — `§ 5`

`Layout` is two things at once. The **eleven display values are the section's
own leaves**, so `.Layout.Flex` is a display value and not a flex container:

`hidden` is the one row whose Tailwind name is not its CSS value: `.Layout.Hidden`
is `display:none`. The flex and grid CONTAINER properties — direction, wrap,
alignment, `gap` — are `Token.Flex`'s, not `Layout`'s.

Everything else in `§ 5` is a **sub-section** beside those leaves.
