# Decision 295 — Request state is atoms, read and written through `use`

`currentUser` is a request-scoped atom, cardume's `Atom<T>` of a `?User`. Its identity is the declaration itself: no string names it, so two parts of the program meet on it only by importing it. `appMiddleware` is a `component` body answering `Component<Response>`, which is what lets it `use` a hook. It takes the setter with `use atomSetter(currentUser)` and sets the user from the `authorization` header before passing the request on. The handler `greet` is a `component` body too, and reads the same atom with `use atomValue(currentUser)`, which answers `?User`.

`main` installs `greet` as the chain's terminal and runs two requests through rakun-service's filter chain. The first carries a token and prints `hello ana at /orders`. The second starts with a new store, so the atom reads `null` and the line is `hello guest at /orders`. A value dies with its request. `LocalKey<T>(name)` and its run-time name clash are gone. The request itself is the root context `RequestContext`, which rakun's pipeline provides, and `rakun-bpp`'s hooks act over the same atoms in a page.

Cells in this repository that prove it: none yet. `rakun-service/filter-chain/middleware` shows the `#[middleware]` chain this example runs through. The atoms arrive with cardume (front 136) and its rakun bridge in front 150 s22 step 7. Until then `from "cardume"` does not resolve.

[draft/main.bp](draft/main.bp)
