# quickstart

## Quickstart

A style is a list of typed tokens: `emilia([...])` answers the class name and
registers the rules on the per-render stylesheet, and `flush()` drains it into the
`<style>` document that goes in the page head. The markup comes first, the
registered stylesheet after it.

In an app the markup is jhonstart's —
`renderToString(div([h1([]), p([])]))` from `import { div, h1, p, renderToString } from "jhonstart"`.
This cell depends on emilia alone, so the markup is a literal carrying the two
class names. `flush()` is a task, hence the `await`.
