# The runtime and the output

> Package: [`rakun-stylesheet`](../docs.md) · index: [`../../docs.md`](../../docs.md)

## The runtime — `emilia(tokens)` and `flush()`

- `emilia(tokens: Token[]) -> string`
  - Maps each token through `tokenToSheet`, merges the sheets in list order,
    names the class `e_` + `hash.contentHash` of the result's rules as
    the document writes them (`classRules`, the class written `\u{1}`),
    registers `(e_<hash>, payload)` on the per-render `Stylesheet`, returns
    the class name.
- `emiliaWith(tokens: Token[], th: Theme) -> string`
  - The same, under an explicit theme. `emilia(tokens)` is
    `emiliaWith(tokens, defaultTheme())`. The theme is an input: a `Md`
    modifier carries the theme's `--breakpoint-md`, so two themes give two
    classes for the same token list.
- `flush() -> string`
  - Drains the `Stylesheet` and renders the **document** — the `@layer`
    statement, the theme layer, the base layer, the components layer, the
    utilities layer and the `@keyframes` blocks — AND clears the cell.
    Per-render contract: two consecutive `flush()` calls emit two
    independent documents; the second has no `@layer utilities` body if no
    `register` happened between them.
- `flushWith(o: Options) -> string`
  - The same, under explicit options. `flush()` is
    `flushWith(defaultOptions())`. See § The cascade and the output.

### Stable hashes — sites collapse

Identical token lists on different elements share one class:

{stable-hashes/src/main.bp}

## The cascade and the output

A token used to lower to a **declaration string**, and a modifier wrapped that
string in braces, so a whole class was one nested block. That shape can only
express what fits inside one class body. A token lowers to a **`Sheet`** now, and
a sheet is a list of rules that can sit anywhere in the document.

{sheet-api/src/main.bp}

| Type | What it is |
| --- | --- |
| `Rule(layer, atRules, selector, declarations, important)` | one style rule — `atRules` outermost-first, `declarations` `;`-joined with no braces around it |
| `Block(header, body)` | a rule that is **not** a style rule: `@keyframes spin` plus its brace-balanced body |
| `Sheet(rules, blocks)` | what a token list produces |
| `Variant(atRule, selector)` | what a modifier is — an at-rule and a selector template, either of which may be empty |
| `Options(theme, base, prefix, important, layers)` | the build-level knobs |

### A selector is a nesting template

`selector` carries **exactly one `&`**, and `&` stands for the class. That one
field covers every variant there is, because each is a template with one `&`:

{variant-templates/src/main.bp}

A selector with **no** `&` is a **literal** selector — that is how the theme
writes `:root` and how a reset writes `html` — and the class name, and therefore
the prefix, never reaches it. A selector with **two or more** `&` is **refused**,
naming the selector. There is no permissive mode and no argument that relaxes it:
with none the variant replaces the rule it was meant to wrap, and with two it
duplicates it, and both are stylesheets that are silently wrong in a browser.

### Nesting runs inner-`&`-first

`nestVariant(s, v)` wraps a sheet in a variant, exactly as CSS nesting does:
the **inner** rule's `&` is what the **outer** variant's selector replaces, and
the outer variant's at-rule is prepended, so the outer modifier is outermost on
both halves.

{nest-variant/src/main.bp}

Blocks pass through untouched — an at-rule does not wrap a keyframes rule.

### Building a sheet

| Function | What it answers |
| --- | --- |
| `emptySheet()` | no rules, no blocks |
| `declSheet(decls)` | one `utilities` rule on the bare `&`; **`declSheet("")` is `emptySheet()`** |
| `staticSheet(layer, selector, decls)` | one rule whose selector is literal |
| `blockSheet(header, body)` | one `@keyframes` block and no rule |
| `mergeSheet(a, b)` | rules then blocks, order preserved — token order is class identity |
| `declarationsOf(s)` | every rule's declaration string, in order |
| `markImportant(s)` | set `important` on every rule; rendering appends `!important` per **declaration** |
| `layerNames()` | `["theme", "base", "components", "utilities"]` — the cascade order, written once |

### Options, and what wins

`renderRule(className, r, o)` renders one rule and `renderDocument(raw, o)` the
whole `<style>` document. The last rule in the stylesheet wins, so the order is
pinned rather than inherited from a `Map`:

1. `@layer theme, base, components, utilities;` when `layers` is on;
2. the **theme** layer — the custom-property block as a `:root` rule;
3. the **base** layer — `o.base`, front 55's reset. It is **opt-in**: the
   default is `withBase(o, [])`, a deliberate inversion of upstream's default;
4. the **components** layer;
5. the **utilities** layer — registered classes in **registration** order;
   within one class, the tokens in the order they were listed, and within one
   class the rules with **no at-rules before** the rules with at-rules, so a
   `md:` override beats the unconditioned utility on a mobile-first read;
6. the `@keyframes` blocks, **outside every layer**, deduplicated by header.
   Keyframes are not subject to the cascade, so their placement is a formatting
   choice; it is written down so it is not re-litigated.

`withLayers(o, false)` emits **no `@layer` token at all** and the same rules in
the same order, so the cascade then rests on document order alone.

`withPrefix(o, "tw_")` renders `.tw_e_1{…}`. rakun-stylesheet's class names are content
hashes over `[a-z0-9_]`, so a prefix is a plain concatenation: upstream's escaped
`.tw\:text-red-500` form has no analogue here, because rakun-stylesheet has no literal
class names to escape. That divergence is intentional.

`withImportant(o, true)` appends `!important` to every declaration of every rule,
the same thing `markImportant` does to one sheet.

[`examples/emilia-cascade/`](../../../examples/rakun-stylesheet/emilia-cascade/) is the worked example:
one card whose hover is a sibling rule, whose breakpoint is a hoisted `@media`
read from the theme, whose reset arrives through `Options`, and whose document
is layered.

### The codec

A host cell stores one string per class, and a `Sheet` is a record tree, so
`encodeSheet`/`decodeSheet` carry it through: records joined by `"\n"` and tagged
`R`/`B`, fields by `"\t"`, the `atRules` list by `"\r"`. The encoding is what the cell
stores; it is not what is hashed — a class name is `e_` + `hash.contentHash` of
`classRules(sheet)`, the sheet's rules as the document writes them with the class written
`\u{1}` (the text `styled` hashes for a component, decision 367), so a class name is still a
pure function of its sheet.

None of the three characters can appear in a rendered declaration. That is an
assumption, so it is **checked** and not assumed: `carriesSeparator(s)` is an
ordinary value, and the suite walks the dispatcher output and the theme's own
strings through it.
