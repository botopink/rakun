# sheet-api

{src/main.bp}

## The cascade and the output

A token used to lower to a **declaration string**, and a modifier wrapped that
string in braces, so a whole class was one nested block. That shape can only
express what fits inside one class body. A token lowers to a **`Sheet`** now, and
a sheet is a list of rules that can sit anywhere in the document.

| Type | What it is |
| --- | --- |
| `Rule(layer, atRules, selector, declarations, important)` | one style rule — `atRules` outermost-first, `declarations` `;`-joined with no braces around it |
| `Block(header, body)` | a rule that is **not** a style rule: `@keyframes spin` plus its brace-balanced body |
| `Sheet(rules, blocks)` | what a token list produces |
| `Variant(atRule, selector)` | what a modifier is — an at-rule and a selector template, either of which may be empty |
| `Options(theme, base, prefix, important, layers)` | the build-level knobs |
