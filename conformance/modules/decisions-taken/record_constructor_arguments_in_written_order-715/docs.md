# Decision 715 — A record constructor's arguments are evaluated in the order written, a spread's source included, each once; a spread copies field values only — the new record's methods are its type's, nothing of the source's behaviour travels.

`Pessoa(nome: say("n"), ..make())` runs its arguments as they are written: `say` prints `n`, then `make` prints `make` and answers a `Visitante`, evaluated once. The fields then apply left to right, the later winning, so the spread's `nome` overwrites the labelled one and the line is `Bia 30`. The second construction spreads `velho`, a `Visitante` with a `saudacao` of its own, into a new `Pessoa` and overrides `idade`: what travels is `velho`'s field values, never its behaviour, so `velho.saudacao()` prints `Welcome, Caio` while `novo.saudacao()` is `Pessoa`'s method and prints `Olá, Caio 42`. `velho` itself is left unchanged (`41`). One rule of evaluation order holds for every call, the spread included: what is written before runs before.

The source here is a record of another type whose fields match `Pessoa`'s; a spread is typed by structure (629).

Cells in this repository that prove it: none yet; rakun's records built by spread are front 150 s29's.

[draft/main.bp](draft/main.bp)
