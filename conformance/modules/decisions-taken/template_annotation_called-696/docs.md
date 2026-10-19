# Decision 696 — A template function is an annotation only when its signature declares the annotated declaration as its second parameter (578 (1): `syntax q: string`, then `syntax decl: unknown`); called as `` f @`…` `` it is `template-annotation-only`, and a template without that parameter at `#[f @`…`]` is `template-annotation-without-decl`.

[draft/main.bp](draft/main.bp)
