# Decision 770 — (a): a package with no `"targets"` holds the intersection of its dependencies' targets (and its workspace's, when it is a member); 676 refuses only a package that declares a target a dependency lacks.

The example is a member of rakun's conformance workspace whose manifest, [draft/botopink.json](draft/botopink.json), writes no `"targets"`. Its one dependency, [erl_host](draft/deps/erl_host/botopink.json), binds a host body on erlang alone and so declares `"targets": ["erlang"]` — the one place the set is stated. The member holds the intersection of its dependencies' targets and of its workspace's (`commonJS`, `erlang`, `beam`): erlang alone. It builds and runs there, printing `built for erlang`, and is not built for commonJS or beam; nothing is refused, because the member declares nothing its dependency lacks. The same member declaring `"targets": ["erlang", "commonJS"]` would be refused `dependency-target-missing` at its manifest (676): only a declared target a dependency lacks is refused, an absent `"targets"` never is.

Built standalone the draft answers so: `build --target erlang` builds and runs it, and asking for commonJS is refused `dependency-target-missing` at the `erl_host` line, the member holding no commonJS target. `decision-cells.py compile` does not read a draft's manifest yet (775), so it builds `main.bp` without `erl_host`; and inside rakun's workspace every draft is refused today, `dependency-target-missing`, its members declaring `beam` over `validation` and `css`, which lack it.

Cells that prove the refusal half: botopink-lang's `dependency_target_missing`, `dependency_target_missing_transitive` and `targets_declared_beyond_dependency`. None in this repository yet.

[draft/main.bp](draft/main.bp)
