# variant-templates

### A selector is a nesting template

`selector` carries **exactly one `&`**, and `&` stands for the class. That one
field covers every variant there is, because each is a template with one `&`:

A selector with **no** `&` is a **literal** selector — that is how the theme
writes `:root` and how a reset writes `html` — and the class name, and therefore
the prefix, never reaches it. A selector with **two or more** `&` is **refused**,
naming the selector. There is no permissive mode and no argument that relaxes it:
with none the variant replaces the rule it was meant to wrap, and with two it
duplicates it, and both are stylesheets that are silently wrong in a browser.
