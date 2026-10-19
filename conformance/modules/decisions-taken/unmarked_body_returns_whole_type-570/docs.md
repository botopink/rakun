# Decision 570 — Without a marker a body returns the whole type: an unmarked `-> Async<T>` / `-> Component<R>` body returning the bare value is a type error; the codemod marks today's such bodies

The example writes each kind of body twice, once with its marker and once without, and shows what
`return` takes in each. `loadPosts` is `async fn … -> Async<string[]>`: the marker makes the body
return the bare list, and the compiler wraps it. `cachedPosts` has no marker, so it is an ordinary
function answering an `Async<string[]>` itself — it returns `Async.resolve([…])`, std's ready
value. A caller sees no difference: `main` writes `await loadPosts()` and `await cachedPosts()`
alike.

The same holds for components. `PostList` is `component fn … -> Component<Element>`, whose body
`use`s a hook and returns the element. `Shell` has no marker: it returns a `Component<Element>`
value, the one `PostList(posts)` makes (calling a component only makes its lambda), and writes no
`use`. Had `cachedPosts` written `return ["a"]`, or `Shell` returned an `Element`, the build would
refuse it as a type mismatch — a `string[]` is no `Async<string[]>` — with a hint naming `async fn`
and `Async.resolve` (for a component, `component fn`).

Proving cells: `conformance/rakun-bpp/server-components/server_component_sequential` and
`server_component_catch` write asynchronous server components; none of this repository shows the
unmarked forms or the refusal yet. The codemod that marks rakun's bodies is 144 B-116 P3, and the
cells come with rakun front 150.

[draft/main.bp](draft/main.bp)
