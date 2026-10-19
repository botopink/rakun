# Decision 140 — A module-level `pub val` crosses modules, and an imported module's body runs first

The program has two modules. `settings.bp` declares a record type `Defaults` holding a rakun
`Response`, and two module-level values: `defaults`, a `Defaults` record, and `greet`, a function
value. Its body also holds `val _loaded`, whose initializer prints `settings loaded`. `main.bp` imports the
record by name and the function under an alias (`settings.greet as hello`) and reads them from
`main`, as it would read a `pub fn`.

The output starts with `settings loaded`: an imported module's body runs once, when the program
starts, before `main` — on erlang and beam too, where the entry calls each imported module's
initialiser first. Then `8080 /api,/health` reads the record's fields across the module boundary,
`Hello, ana!` applies the imported function value through its alias, and `listening on 8080` calls
a method of the imported record. Nothing is a function returning the values; the values themselves
cross.

Proving cells: `conformance/rakun-ssr/commands` (its generated entry registers every page before
`main`, decision 140).

[draft/main.bp](draft/main.bp)

[draft/settings.bp](draft/settings.bp)
