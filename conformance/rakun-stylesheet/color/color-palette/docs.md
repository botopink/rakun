# color-palette

{src/main.bp}

### Color — the palette

Twenty-six families of eleven shades, and **the token emits a reference, not a
value**:

The families are the seventeen chromatic (`Red Orange Amber Yellow Lime Green
Emerald Teal Cyan Sky Blue Indigo Violet Purple Fuchsia Pink Rose`) and the
nine neutral (`Slate Gray Zinc Neutral Stone Mauve Olive Mist Taupe`); every
one of them answers all eleven shades `50 100 200 300 400 500 600 700 800 900
950`.

`var(--color-red-500)` is byte-equal with what upstream's own `.text-red-500`
rule emits, and it means a project that overrides `--color-red-500` moves every
rule that names it. The numbers live in the theme, not in the rule — see
[The colour palette](#the-colour-palette).

**All 286 cells are reachable.** Six of them — `.Color.Red.{100,500,700}` and
`.Color.Gray.{100,500,700}` — used to compile in no spelling, because the
compiler resolved a leading-dot section path by scanning every registered enum
(the synthesised section enums included) and returning the first whose tree
carried the path, without consulting the expected type: `Token` carries
`Color.Red.500` and so does `Token.Border.Color`, whose Red and Gray also run
100/500/700, so the winner was decided by hash order. It red at the call site
rather than emitting the wrong CSS. The resolver now prefers the enum the
expected type names, accepts the fully qualified `Token.Color.Red.500`, and
refuses an ambiguous path instead of guessing.

`Token.Border.Color` has since been widened to this same full grid (front 40),
so the two sections now carry the same 286 cells and the same eleven shades.
That is **not** what fixed the collision, and it would not have: the resolver
fix is what makes both reachable, and the standing rule is that a collision
like this is never resolved by adding or renaming a type to flip a hash.
