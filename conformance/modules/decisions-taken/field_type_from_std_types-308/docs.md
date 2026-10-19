# Decision 308 — `Field<T>` is std's `compiler.Field<T>`, and `Type.keys(T)` names it:

A recipe type and its keys. `Type.keys(Recipe)` answers std's field type of `Recipe` — imported as `compiler.Field` and written `Field<Recipe>` — so `RecipeKey` and the parameter type of `describe` are one type. `describe` matches the key exhaustively with `.title`, `.minutes` and `.serves`; `main` walks `RecipeKey.all()` in declaration order, printing `title = Feijoada`, `minutes = 180 min`, `serves = serves 6`, then `RecipeKey.of("minutes")` finds `minutes` by its text and `RecipeKey.of("salt")` answers `null`, printed `none`.

There is no `recipe.get(key)`: reading a record through a key is the `case` the program writes. The same `Field<T>` is what a decorator signature names (`comptime at: ?Field<T>`) and what `compiler.fields(decl)` hands rakun's decorators — rakun-data's `#[entity]` reads its columns through it.

Cells of this repository that prove it: none yet — rakun 08 s4 (the `Field` keys at run time) brings the code; rakun-data's `orm/entity.bp` reads `compiler.Field` at build only.

[draft/main.bp](draft/main.bp)
