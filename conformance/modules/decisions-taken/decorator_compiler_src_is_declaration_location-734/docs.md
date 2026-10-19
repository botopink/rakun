# Decision 734 — (a): `compiler.src()` in a decorator body is legal and answers the annotated declaration's location (718, 575 (3)); 403 survives as "no route from a file's location".

A page decorator in the shape of rakun-bpp's `#[page]`. The route reaches it as an argument (`#[page("/")]`, `#[page("/about")]`), never from where the file sits. Its body calls `compiler.src()`, which answers the annotated declaration's location — not the decorator's — and records it with the route as a `PageAt` meta. At run time the program reads each meta through `compiler.typeInfo(…).meta(PageAt)` and prints the route with the file and line of `home` and of `about`.

`decl` carries no location of its own (`decl.loc` does not exist); the location is the compiler's member.

Cells of this repository that prove it: none yet — rakun-bpp's `#[page]` records its location so with front 150.

[draft/main.bp](draft/main.bp)
