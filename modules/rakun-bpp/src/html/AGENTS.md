# rakun-bpp/modules/rakun-bpp/src/html/

> Path: `repository/rakun-bpp/modules/rakun-bpp/src/html/`
> Parent (workspace): [`../../../AGENTS.md`](../../../AGENTS.md) · Core: [`../../rakun-bpp/src/AGENTS.md`](../../rakun-bpp/src/AGENTS.md)
> Front: [`specs/1.0.12-beta/08-bpp/118-bpp-components/`](../../../../../specs/1.0.12-beta/08-bpp/118-bpp-components/README.md)

Source for the `rakun-bpp` member — what `from "rakun-bpp"` resolves
to: the `` html @`…` `` template language. Cut out of the core by front 95; it
returns to the core as its `pub default fn` at `05-jhonstart/26` step 0
(decision 200). Its manifest `../botopink.json` lists `files` `[root.bp,
html.bp]` and depends on the core with `{ "rakun-bpp": { "workspace": true }
}`; the core does not depend on this member. The expansion resolves every tag
in the CALLER's scope, so a consumer imports the builders and components it
writes; the names the expansion itself writes (`htmlText`, `htmlNode`,
`htmlAttr`, …) are this module's and resolve here (decision 112's hygiene).

| File | Kind | Provides |
|---|---|---|
| `root.bp` | module-tree root | `pub mod html;` |
| `html.bp` | **compiled** | `#[bpp.html] pub fn html(syntax template: string) -> Element` — std's `#[bpp.html]` (decision 361, `import {bpp} from "std";`) marks it the markup's unfold target, the one declaration the toolchain finds in the package `"bpp"` names (until `05-jhonstart/26` step 0 moves it into the core as its default function, the core marks no `#[bpp.html]` and `"bpp": "rakun-bpp"` is refused at the key); the grammar and lowering in its header: elements and components (`<Card a="x" b={v}>kid</Card>` → `Card(a: "x", b: v, children: kid)`), `<>`/`<Fragment>`, `{expr}` holes (`htmlNode` over core `Node`, decision 191), `${expr}` text holes, attributes `name="text"` / `name={expr}` (a `string`, a `bool` bare or absent, a `?string` absent when null; a `data-*` one a `string`) / bare, named as decision 351 names them — a multi-word name camelCase (`tabIndex`, `ariaLabel`, `httpEquiv`) rendered in HTML's spelling (`htmlName`: `tabindex`, `aria-label`, `http-equiv`), `data-*` the one kebab-case family —, void and self-closing tags in place, comments and `<!doctype>` rendered, `script`/`textarea`/`title` bodies unparsed (`style` kept for `#[isInline]`, 119), markup inside a lambda body, an `if` / `else` block and a `case` arm (an `if` without `else` renders nothing), `<slot />` / `<slot>fallback</slot>` over the `children` parameter, tag annotations, each run over the tag's declaration handle (`compiler.tagDecl`, `compiler.annotate`, decision 302) and read back by type — `RawBody`, which `#[isRaw]` records, keeps the body as text; an annotation whose meta `html` does not read is another reader's. Refusals located with `compiler.fail(message, at: template, span: Span(…))`: an unbound tag or annotation, a mismatched / unexpected / unclosed tag, `[name]={…}`, `class:list` / `set:html` / `set:text` / any `prefix:name`, `slot="…"` and `<slot name>` (props-e), a spread on a component (props-f), a spread on an element (351: it takes the element's props record, which a template cannot build yet), a kebab-case attribute but `data-*` (naming its camelCase form), an event attribute (`onClick`, 351), markup as an operand, an unknown entity, `<style>` in markup (decision 338: the style section or `use styled`). Also `pub fn isRaw` and its `RawBody`, `classList`, `classIf`, `hasContent`, the private runtime helpers the expansion calls, and the private helpers `html`'s body calls at compile time |

Exercised by `../test/` on both targets — `template_test.bp` (steps 1–5),
the three spec examples landed as `template_expressions_example_test.bp`,
`components_and_slots_example_test.bp`, `directives_example_test.bp`,
`defects_test.bp` (the four defects front 118 found), `view_test.bp`
(decision 276), `platform_test.bp` (what a template body may write),
`html_test.bp` / `elements_test.bp` — and by the workspace's
`refusals/html_*` cases (each compile-time refusal, its message pinned).

## Comptime constraints

`html`'s body runs on the comptime runtimes — BEAM for an erlang build, wat for
a commonJS one. Measured by `../test/platform_test.bp` (front 118 step 0), on
both:

| Construct | Result |
|---|---|
| a call to a function of this module (private or `pub`, recursive or not) or an imported one | works — the template module carries the functions the body reaches (decision 331); `html`'s pure helpers (`lit`, `decode`, `textOut`, `closeTagCode`, …) are such functions |
| recursion | works through a function; a lambda cannot name itself (`unbound variable`, a `language-gaps.md` row) |
| a labelled tuple element read by its label (`t.kind`) | works |
| a large body in one function (`html`'s own) | works — a variable holds a slot of the runtime's frame only while it is live |
| `xs.at(i)` | works (`?T`, read with `??`) |
| a `?T` binding read with `??`, `if (x == null) … else x.f` | works |
| an `i32` reassigned inside a nested lambda (`forEach` bodies) | works |
| a `//` comment in the body | works |

One more, met while writing the body (a `language-gaps.md` row):

- **a lambda that writes a `var` of the body** must be called only at statement
  position of the body, never from another lambda (decision 148,
  `captured-var-write`); a lambda that only reads takes the state as arguments,
  since on the BEAM a closure holds a copy of what it captured when made. The
  parser's state is the body's own `var`s, so nested markup is walked with an
  explicit frame stack written by such lambdas (`push`, `pop`, …).

The built code is the markup's code alone: the compiler locates it by its
expansion (decision 429), so two expansions in one module keep their own plans
— a default argument filled for one never lands on a call of the other — and a
diagnostic in it points at the literal.
