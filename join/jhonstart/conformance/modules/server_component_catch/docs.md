A server component that only loads data is `fn … -> @Task<Element>`; the return
type is the effect. A load that may fail answers a `@Result` and the component
recovers with `try await … catch <fallback>`. `renderServerComponent` is called
with a lambda — `{ -> PostPage(params) }` — never a bare function name.
