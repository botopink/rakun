# Decision 737 — (a): a component takes its props as plain parameters or as one record parameter `..props: R` — 529 (1), (2) stand whole.

The example declares two components, one in each form a component takes its props in, and calls
each from markup. `Card` takes plain parameters, `title: string` and `featured: bool = false`:
`<Card title="Olá" featured />` passes each attribute as the labelled argument of that name — the
bare `featured` is `true` — and `<Card title="Tchau" />` leaves `featured` at its default.
`Panel` takes one record parameter, `..props: PanelProps`: from outside, the record's fields are
its parameters, so `<Panel {..base} featured />` spreads the record `base` and overrides one field,
and the body reads them as `props.title` and `props.featured`.

The two forms render alike; `main` prints the page holding the three tags. An attribute that names
no parameter (`<Card subtitle="x" />`) is refused at the attribute, and a spread into `Card`, whose
parameters are plain, is refused at the spread: a spread goes only into a record parameter.

Proving cells: `conformance/rakun-bpp/components/render_nested` renders nested components through
the builders; none of this repository passes tag attributes as props yet. The cell
`component_props_plain_or_record` comes with `machine-1/144` B-27 and rakun front 150 s34.

[draft/main.bp](draft/main.bp)
