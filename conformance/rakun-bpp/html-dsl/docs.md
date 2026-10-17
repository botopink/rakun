# The `html` DSL

> Package: [`rakun-bpp`](../docs.md) · index: [`../../docs.md`](../../docs.md)

`html` captures markup **unevaluated** (`@Expr<string>` — the `"""…"""`
triple-quoted literal) and expands it, at compile time, into the `Element` builder
pipeline — at zero runtime cost. Its body is a real markup front-end (a lexer →
token stream → stack parser, the sibling of query's `` query @`…` `` SQL form), so it
returns `@ExprCustom<Element>`: the executable builder code PLUS a generic
`CustomNode` reference tree the language server reads to highlight and navigate
the markup (tags, attributes, text), with each `<div>` tied to the builder it
resolves to. `` val page = html @`…` `` compiles straight to the builder calls;
`html` never reaches codegen.

{html_dsl_hole/src/main.bp}

The expansion is:

- a lowercase `<tag>` → a bare `tag([...])` call resolved in **the caller's
  scope** (the expr-template `lookup` model), so the caller must `import` the
  builders the markup names (`div`/`p`/`li`/…); an unknown tag surfaces as an
  unbound diagnostic at the call site, pointing inside the template;
- a text run → a `text("…")` leaf (whitespace-only runs between tags are dropped,
  so the markup can be indented);
- each `${expr}` → the caller's already-typed expression, spliced as a
  `text(<expr>)` child (`` html @`<li>item ${n.toString()}</li>` `` →
  `li([text("item "), text(n.toString())])`).

**A tag from `elements.bp` is resolved the same way** — there is no wildcard
import and no implicit prelude, so the consumer names every tag the markup
uses:

{html_dsl_prelude/src/main.bp}

(`bracketPair` is named because a `[attr]={expr}` hole lowers to a call to it.)
A tag that is not imported is an unbound-name diagnostic at the call site,
which names the tag — the one case where the surface being a plain set of
functions is an advantage.

A single root tag is returned bare; multiple top-level siblings wrap in
`fragment([...])` (which then must be imported too). Attributes (`<div
class="card">`) are parsed and surface in the reference tree for tooling, but —
as before — do not change the built `Element` (the builders take only
`Children`). A mismatched, unexpected, or unclosed tag is a `q.failAt`
diagnostic pinned to the offending tag inside the template (e.g. `html
"""<div><p>hi</div>"""` → *mismatched closing tag `</div>`, expected `</p>`*),
not a whole-template error. Bare `html`/`div`/… are reached unqualified after
`import … from "rakun-bpp"` / `from "rakun-bpp"` via the generic
loader-bare binding. Capitalized
`<Component/>` markup lookup is a **future layer** — today a component is an
ordinary `fn(...) -> Element` (its body may itself author `` html @`…` ``) reused
by a plain call. See `examples/rakun-bpp/jhonstart-markup`.
