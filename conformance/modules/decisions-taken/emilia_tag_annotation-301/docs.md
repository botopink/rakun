# Decision 301 — emilia reaches markup as a tag annotation of its own:

The example writes rakun-stylesheet's tokens on a tag as an annotation of their own. In `page`, the
`<h1>` carries `#[emilia(.Text.Size.X3xl, .Text.Bold)]`: the tokens are known at build, so their
order — which is the class's identity — is fixed where they are written, the theme check applies,
and the class and its rules are computed while the program is built and recorded as rakun-style's
`StyledMeta` on that tag. The `<button>` carries two annotations: `#[styled(primary)]`, rakun-bpp's,
which takes only a rakun-style component of the application (`primary`, from `buttons.bp`) and
records a `ClassName` meta; and `#[emilia(.Pad.All.__4)]`. rakun-bpp's `html` merges each recorded
class into the tag's `class` after the written `send`, in annotation order, and names no styling
library. The rendered markup prints `<h1 class="e_…">` and `<button class="send s_… e_…">`. No
`class={emilia(tokens)}` hole and no `fn …Tokens() -> Token[]` helper is written: a style chosen at
run time picks between annotated branches.

Proving cells: none in this repository yet; `conformance/rakun-stylesheet/getting-started/class-on-element`
shows the class reaching an element in today's run-time spelling, and the annotation comes with
119 step 4 and `06-emilia/34` step 1.

[draft/main.bp](draft/main.bp)

[draft/buttons.bp](draft/buttons.bp)
