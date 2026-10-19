# Decision 347 — A method-level decorator sees its own method; the type-level decorator reads the type.

The program is a rakun controller with two handlers. The routes come from the type-level decorator: `#[restController]` sees `UserController` whole, reads the `#[route("/users")]` prefix and every method with its annotations, and registers `GET /users/:id` for `show` and `GET /users/:id/posts` for `posts`. Neither `#[getMapping]` knows the prefix: on its own, a method marker only checks where it is placed. `#[traced]` is the program's own method decorator. It sees its method, `show(self, req)` returning `Response`, and refuses a handler that answers anything else, but it has no owner to read: what links a method to its type is always written by the type's decorator. The program prints `user 7`, `posts of 7` and `404` (no route is registered for `/users` itself). The order the decorators run in does not change any of this.

Cells in this repository that prove it: `rakun/web/usage` (a `#[restController]` whose `#[route]` prefix and `#[getMapping]` method make one route).

[draft/main.bp](draft/main.bp)
