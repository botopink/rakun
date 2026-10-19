# Decision 666 — The `Decorator` type goes: a decorator is a function (663) and its name at build is a declaration handle; two declarations are compared with `compiler.same(a, b)`.

The example counts a controller's handlers by the decorator that marks each. The program's decorator
`inventory` walks `NoteController`'s methods at build and, for each annotation, asks
`compiler.same(a.decorator, getMapping)` and `compiler.same(a.decorator, postMapping)`. A decorator
is a function, and its name at build is a declaration handle: `a.decorator` is the handle of the
decorator that annotation calls, and `compiler.same` answers whether two handles are one declaration.
The third method is written `#[post("/notes")]` through an import alias, and `compiler.same` still
answers `true` against `postMapping`: the alias is resolved. A same-named decorator of another module
would answer `false`.

No `Decorator` type is involved: the handles are `unknown`, read through `compiler.*`, and `==` between
them means nothing. `main` prints `NoteController: 2 read, 1 write`.

Proving cells: none in this repository; rakun's controllers still read a method's annotations by
their names in text (`a.name == "getMapping"`), which 165 s10 rewrites to `compiler.same`.

[draft/main.bp](draft/main.bp)
