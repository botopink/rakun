# Decision 529 — A component's props are plain parameters or one record parameter `..props: R`; `..` is the one spelling of the rest; a `.bpp` unfolds to `(..props: Props)`.

Two rakun-bpp components. `Badge` takes its props as plain parameters, `tone` with a default. `Card` takes the record parameter `..props: CardProps` beside the plain `footer`: from outside, `title` and `featured` are its parameters, passed by label, and the body reads `props.title` and `props.featured`. `Card` is called four ways — by labels, with the spread `..base` of a `CardProps` value plus `featured: true`, as the tag `<Card title="Olá" featured footer="tag" />` in the `html` markup (the bare `featured` attribute is `true`), and as the tag with the spread `{..base}` — and each renders a `div` holding the title, with `* ` before it when featured, and the badge `info: <footer>`. The last line renders `Badge` alone, `warn: alone`.

Refused: an attribute naming no parameter, or of the wrong type, at the attribute; a spread into `Badge`, whose parameters are plain; a second record parameter, or a name both in `CardProps` and beside it, at the declaration. `...` is only the inclusive range — the formatter migrates an old `...` spread to `..`. A `.bpp` file declaring `type Props(…)` unfolds to `pub default fn (..props: Props) -> View`.

Cells of this repository that prove it: none yet — `2-libraries/149` (jhonstart, now rakun-bpp) brings the code; `rakun-bpp/client-boundary/client_props_whitelist` declares a props record but passes it whole.

[draft/main.bp](draft/main.bp)
