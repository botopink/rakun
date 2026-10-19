# Hooks

> Package: [`rakun-bpp`](../docs.md) · index: [`../../docs.md`](../../docs.md)

Hook **bodies are pure and synchronous** — they model the first render (the
server pass): `state` yields its initial value, `memo` computes eagerly,
`effect` is a no-op, `ref`/`reducer` seed their boxes. `use f(x)` lowers to
`f(x)` on **every** backend — nothing is renamed to React's `useState`, no
dependency array is inferred (a hook that takes one declares it: `memo(compute,
deps)`). Client re-render reactivity is the **client runtime**'s job: see
*Client runtime* below.

| Hook | Returns (via `use`) | Notes |
|---|---|---|
| `state<T>(initial)` | `State<T>` = `{value: T, set: fn(next: T)}` | local state + setter |
| `effect(run, deps)` | `#()` | side effect after render (void) |
| `memo<T>(compute, deps)` | `T` | memoized value (computed eagerly in SSR) |
| `ref<T>(initial)` | `#(current: T)` | mutable handle |
| `reducer<S,A>(reduce, init)` | `#(state: S, dispatch: fn(action: A))` | reducer state |

Custom hooks compose the primitives — a noun for a name and a
`Component<_>` return:

{hook_noun_custom/src/main.bp}
