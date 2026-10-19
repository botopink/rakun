# Decision 524 — `botopink format` is applied, never checked: the commit hook formats the commit's `.bp` files; the seven rewrites are the canonical form; C-13 becomes formatting.

A rakun handler and its caller, as `botopink format` left them. The `if` in `greet` was written as a block, `{ return Response.withStatus(…); };`, with a `;` after its closing brace: the parser accepts it and the formatter removes the `;` and prints the one-statement block in its canonical one-line form — a rewrite applied, never a check that fails. The commit hook of this repository formats each `.bp` as it enters the commit, so the draft holds the canonical text. The program prints `200 Hello, ana!`, then `400 a name is required`.

What stays an error is a language rule the parser or the checker owns — a `{` without `->` used as a function, a reserved word as a name — and the formatter never stands in for it.

Cells of this repository that prove it: none — the rule is the formatter's and the hook's; every `.bp` of this repository is formatted by its commit hook (2-libraries/150, 165).

[draft/main.bp](draft/main.bp)
