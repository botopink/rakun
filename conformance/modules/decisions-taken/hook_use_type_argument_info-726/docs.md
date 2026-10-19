# Decision 726 — A type argument's `compiler.Info<unknown>` in a `HookUse` carries the type's whole declaration.

The example reads, at build, what a page's `use` names as a type argument. `BlogPost` writes
`use params<BlogParams>()`; the decorator `checkedParams` walks `compiler.hooks(decl)` to that
`use` and finds `BlogParams` in its type arguments as a `compiler.Info<unknown>` — the type's whole
declaration, not a name string. `compiler.fields(t)` gives its two fields, each a
`compiler.Field` with its annotations: `slug` carries `#[required]`, `page` none, and the
decorator tells the marker apart with `compiler.same(a.decorator, required)`. It records the
required names as typed meta, `ParamsCheck(required: ["slug"])`, which `main` reads back with
`compiler.typeInfo(BlogPost).meta(ParamsCheck)` and prints.

The list is never empty because the type's declaration was not published: every module's type
declarations are visible to the build session, so an empty `fields` would mean a type with no
fields.

Proving cells: none in this repository yet; they come with `machine-1/144` B-17 and rakun front
150 s23, which reads a page's `params<T>` this way.

[draft/main.bp](draft/main.bp)
