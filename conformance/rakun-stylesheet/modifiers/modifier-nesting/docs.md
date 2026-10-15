# modifier-nesting

{src/main.bp}

Modifiers nest, and the OUTER one is outermost in the selector and in the
at-rule list alike — which is how a `dark:md:hover:` chain reads upstream:

A breakpoint RANGE is nesting too, not a variant of its own — upstream's
`md:max-xl:` is `Token.Md([Token.MaxXl([…])])`. Every breakpoint reads the
theme's `--breakpoint-*` entry, both ways round, so overriding the ladder
moves the queries and the class hashes with it.

**Breakpoints — min-width, read from the theme's `--breakpoint-*` ladder**

| upstream | rakun-stylesheet | CSS |
| --- | --- | --- |
| `sm:` | `Token.Sm(inner)` | `@media (width >= 40rem){…}` |
| `md:` | `Token.Md(inner)` | `@media (width >= 48rem){…}` |
| `lg:` | `Token.Lg(inner)` | `@media (width >= 64rem){…}` |
| `xl:` | `Token.Xl(inner)` | `@media (width >= 80rem){…}` |
| `2xl:` | `Token.X2xl(inner)` | `@media (width >= 96rem){…}` |

**Breakpoints — max-width, the same ladder read the other way**

| upstream | rakun-stylesheet | CSS |
| --- | --- | --- |
| `max-sm:` | `Token.MaxSm(inner)` | `@media (width < 40rem){…}` |
| `max-md:` | `Token.MaxMd(inner)` | `@media (width < 48rem){…}` |
| `max-lg:` | `Token.MaxLg(inner)` | `@media (width < 64rem){…}` |
| `max-xl:` | `Token.MaxXl(inner)` | `@media (width < 80rem){…}` |
| `max-2xl:` | `Token.MaxX2xl(inner)` | `@media (width < 96rem){…}` |

**Dark mode and the other media features**

| upstream | rakun-stylesheet | CSS |
| --- | --- | --- |
| `dark:` | `Token.Dark(inner)` | `@media (prefers-color-scheme: dark){…}` |
| `print:` | `Token.Print(inner)` | `@media print{…}` |
| `portrait:` | `Token.Portrait(inner)` | `@media (orientation: portrait){…}` |
| `landscape:` | `Token.Landscape(inner)` | `@media (orientation: landscape){…}` |
| `motion-safe:` | `Token.MotionSafe(inner)` | `@media (prefers-reduced-motion: no-preference){…}` |
| `motion-reduce:` | `Token.MotionReduce(inner)` | `@media (prefers-reduced-motion: reduce){…}` |
| `contrast-more:` | `Token.ContrastMore(inner)` | `@media (prefers-contrast: more){…}` |
| `contrast-less:` | `Token.ContrastLess(inner)` | `@media (prefers-contrast: less){…}` |
| `forced-colors:` | `Token.ForcedColors(inner)` | `@media (forced-colors: active){…}` |

**Interaction state**

| upstream | rakun-stylesheet | CSS |
| --- | --- | --- |
| `hover:` | `Token.Hover(inner)` | `@media (hover: hover){&:hover{…}}` |
| `focus:` | `Token.Focus(inner)` | `&:focus{…}` |
| `focus-within:` | `Token.FocusWithin(inner)` | `&:focus-within{…}` |
| `focus-visible:` | `Token.FocusVisible(inner)` | `&:focus-visible{…}` |
| `active:` | `Token.Active(inner)` | `&:active{…}` |
| `visited:` | `Token.Visited(inner)` | `&:visited{…}` |
| `target:` | `Token.Target(inner)` | `&:target{…}` |
| `open:` | `Token.Open(inner)` | `&:is([open], :popover-open, :open){…}` |
| `inert:` | `Token.Inert(inner)` | `&:is([inert], [inert] *){…}` |

**Form state**

| upstream | rakun-stylesheet | CSS |
| --- | --- | --- |
| `disabled:` | `Token.Disabled(inner)` | `&:disabled{…}` |
| `enabled:` | `Token.Enabled(inner)` | `&:enabled{…}` |
| `checked:` | `Token.Checked(inner)` | `&:checked{…}` |
| `indeterminate:` | `Token.Indeterminate(inner)` | `&:indeterminate{…}` |
| `default:` | `Token.Default(inner)` | `&:default{…}` |
| `optional:` | `Token.Optional(inner)` | `&:optional{…}` |
| `required:` | `Token.Required(inner)` | `&:required{…}` |
| `valid:` | `Token.Valid(inner)` | `&:valid{…}` |
| `invalid:` | `Token.Invalid(inner)` | `&:invalid{…}` |
| `user-valid:` | `Token.UserValid(inner)` | `&:user-valid{…}` |
| `user-invalid:` | `Token.UserInvalid(inner)` | `&:user-invalid{…}` |
| `in-range:` | `Token.InRange(inner)` | `&:in-range{…}` |
| `out-of-range:` | `Token.OutOfRange(inner)` | `&:out-of-range{…}` |
| `placeholder-shown:` | `Token.PlaceholderShown(inner)` | `&:placeholder-shown{…}` |
| `autofill:` | `Token.Autofill(inner)` | `&:autofill{…}` |
| `read-only:` | `Token.ReadOnly(inner)` | `&:read-only{…}` |

**Structural position**

| upstream | rakun-stylesheet | CSS |
| --- | --- | --- |
| `first:` | `Token.First(inner)` | `&:first-child{…}` |
| `last:` | `Token.Last(inner)` | `&:last-child{…}` |
| `only:` | `Token.Only(inner)` | `&:only-child{…}` |
| `odd:` | `Token.Odd(inner)` | `&:nth-child(odd){…}` |
| `even:` | `Token.Even(inner)` | `&:nth-child(even){…}` |
| `first-of-type:` | `Token.FirstOfType(inner)` | `&:first-of-type{…}` |
| `last-of-type:` | `Token.LastOfType(inner)` | `&:last-of-type{…}` |
| `only-of-type:` | `Token.OnlyOfType(inner)` | `&:only-of-type{…}` |
| `empty:` | `Token.Empty(inner)` | `&:empty{…}` |
| `nth-N:` | `Token.Nth(index, inner)` | `&:nth-child(3){…}` |
| `nth-last-N:` | `Token.NthLast(index, inner)` | `&:nth-last-child(5){…}` |

**Pseudo-elements**

| upstream | rakun-stylesheet | CSS |
| --- | --- | --- |
| `before:` | `Token.Before(inner)` | `&::before{…}` |
| `after:` | `Token.After(inner)` | `&::after{…}` |
| `first-letter:` | `Token.FirstLetter(inner)` | `&::first-letter{…}` |
| `first-line:` | `Token.FirstLine(inner)` | `&::first-line{…}` |
| `placeholder:` | `Token.Placeholder(inner)` | `&::placeholder{…}` |
| `file:` | `Token.File(inner)` | `&::file-selector-button{…}` |
| `marker:` | `Token.Marker(inner)` | `& *::marker{…}`, `&::marker{…}`, and the same two for `::-webkit-details-marker` |
| `selection:` | `Token.Selection(inner)` | `& *::selection{…}`, `&::selection{…}` |
| `backdrop:` | `Token.Backdrop(inner)` | `&::backdrop{…}` |

**Parent state — the `.group` class is the consumer's, never rakun-stylesheet's**

| upstream | rakun-stylesheet | CSS |
| --- | --- | --- |
| `group-hover:` | `Token.GroupHover(inner)` | `&:is(:where(.group):hover *){…}` |
| `group-focus:` | `Token.GroupFocus(inner)` | `&:is(:where(.group):focus *){…}` |
| `group-active:` | `Token.GroupActive(inner)` | `&:is(:where(.group):active *){…}` |
| `group-visited:` | `Token.GroupVisited(inner)` | `&:is(:where(.group):visited *){…}` |
| `group-disabled:` | `Token.GroupDisabled(inner)` | `&:is(:where(.group):disabled *){…}` |
| `group-open:` | `Token.GroupOpen(inner)` | `&:is(:where(.group):is([open], :popover-open, :open) *){…}` |

**Sibling state — the `.peer` class is the consumer's, never rakun-stylesheet's**

| upstream | rakun-stylesheet | CSS |
| --- | --- | --- |
| `peer-hover:` | `Token.PeerHover(inner)` | `&:is(:where(.peer):hover ~ *){…}` |
| `peer-focus:` | `Token.PeerFocus(inner)` | `&:is(:where(.peer):focus ~ *){…}` |
| `peer-active:` | `Token.PeerActive(inner)` | `&:is(:where(.peer):active ~ *){…}` |
| `peer-checked:` | `Token.PeerChecked(inner)` | `&:is(:where(.peer):checked ~ *){…}` |
| `peer-invalid:` | `Token.PeerInvalid(inner)` | `&:is(:where(.peer):invalid ~ *){…}` |
| `peer-required:` | `Token.PeerRequired(inner)` | `&:is(:where(.peer):required ~ *){…}` |
| `peer-disabled:` | `Token.PeerDisabled(inner)` | `&:is(:where(.peer):disabled ~ *){…}` |
| `peer-placeholder-shown:` | `Token.PeerPlaceholderShown(inner)` | `&:is(:where(.peer):placeholder-shown ~ *){…}` |

**Writing direction and descent**

| upstream | rakun-stylesheet | CSS |
| --- | --- | --- |
| `rtl:` | `Token.Rtl(inner)` | `&:where(:dir(rtl), [dir="rtl"], [dir="rtl"] *){…}` |
| `ltr:` | `Token.Ltr(inner)` | `&:where(:dir(ltr), [dir="ltr"], [dir="ltr"] *){…}` |
| `*:` | `Token.Children(inner)` | `:is(& > *){…}` |
| `**:` | `Token.Descendants(inner)` | `:is(& *){…}` |

**The priority wrapper — not a variant, a flag on every rule it wraps**

| upstream | rakun-stylesheet | CSS |
| --- | --- | --- |
| `…!` | `Token.Important(inner)` | `!important` on every declaration it wraps |

**Named groups and peers — `group/card`, `peer/field`**

`Token.GroupNamed(name, inner)` and `Token.PeerNamed(name, inner)` name the
`.group` / `.peer` class of the unnamed state tokens in `inner`; every state
above is available named, and any other token in `inner` is folded unchanged.
