# Decision 670 — Any function declared `-> anytype` builds a type; std's `Type` functions are the first of them, not a privilege.

`view` is the program's own function declared `-> anytype`: it takes a type as a `comptime t: type<T>` and builds a new record type from `t`'s fields minus `password`. `pub val PublicUser = view(User);` is evaluated at build and makes `PublicUser` a type, named by its `val` and usable in every type position, as `publicOf`'s return type shows. std's `Type.partial(User)` is the same kind of function, resolved through the import like any other, so `UserPatch` is a type too, with every field optional. The program prints `ana ana@example.com` and `ana@rakun.dev`.

A `-> anytype` function has only `comptime` parameters: a call with a run-time argument is `comptime-arg-not-known`, and a call anywhere but a module-level `val`'s initializer, `val t = view(User);` inside `main` for instance, is refused at the call, `anytype-outside-type-val`. The checker keeps no list of std names.

Cells in this repository that prove it: none yet. rakun's typed views over its records (rakun-data's entities and rakun's derived config types) come with front 165 s11 and 144 B-140.

[draft/main.bp](draft/main.bp)
