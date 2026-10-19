# Components

> Package: [`rakun-bpp`](../docs.md) · index: [`../../docs.md`](../../docs.md)

## Loading

`rakun-bpp` is a package of the rakun workspace, the member `modules/rakun-bpp/`;
`from "rakun-bpp"` resolves to that member, never to the workspace. Declare it as
a dependency — `dependencies` is the object form, exactly one source per entry
(decision 76) — and import what you need:

```jsonc
// botopink.json
{ "name": "myapp", "target": "commonJS", "src": "src/", "entry": "main.bp",
  "dependencies": { "rakun-bpp": { "git": "https://github.com/botopink/rakun.git", "branch": "feat" } } }
```

```jsonc
// …or, from a member of the rakun workspace — which is what
// examples/rakun-bpp/*/ use:
{ "dependencies": { "rakun-bpp": { "workspace": true } } }
```

{imports_surface/src/main.bp}

The loader walks up from `cwd` and, at each ancestor, considers these roots
(nearest-first): the ancestor itself when its `botopink.json` is a workspace,
the compiler's bundled `libs/`, a `repository/` directory, a legacy flat `libs/`,
then `.botopinkbuild/deps/`. A root contributes every immediate child holding a
`botopink.json` **and every member of a workspace found there, named by its own
manifest** — so the rakun workspace contributes `rakun-bpp` (the member
`modules/rakun-bpp/`) beside its other packages and examples, and never the
workspace itself. The member's `files` — `root.bp`, `element.bp`, `hooks.bp`,
`router.bp`, `elements.bp`, `client_runtime.bp`, `server.bp`, …, and the
sub-folder modules `html/`, `link/`, `forms/`, `testing/` — are the only modules a
consumer sees. A `{ "workspace": true }` dependency consults no root at all.
Nothing about rakun-bpp is embedded; the compiler core never names it.

## Component model

A **component** that activates hooks is a `fn(...) -> Component<Element>`
(one that activates none is an ordinary `fn … -> Element`). A **hook** is a
function named by its **noun** — `state`, `effect`, `memo`, `ref`,
`reducer`, `router`; never a `use` prefix in the name — returning
`Component<_>`. There is no annotation: **the return type is the
effect** (decisions 118 and 128 of botopink 1.0.10-beta). `Element` carries the
tree: `implement Renderable`. The keyword `use` is the activation:
`val c = use state(0)` is legal only in a body whose return is
`Component<_>` — a component or a custom hook — and every
`use` sits in the body's **static prefix** — before any `if`, `case`, `loop` or
`return`, at any nesting. A body with any other return that activates a hook is
`use-without-context-effect`. All of this is the language's context-inference
(decisions 88, 104, 118, 128 of 1.0.10-beta), not rakun-bpp. `Component`
extends `Task`, so a component or hook may also `await`; it may `throw` / `try`
only when its `T` is a `Result` — a component returns `Element`, so it handles
errors in its own body (`try … catch`, `case`; decision 121). On commonJS every
`Component` body is an `async function`: a component's caller `await`s it.

{counter_ssr/src/main.bp}

Children are written as a **list** (`div([a, b])`). A hook yields its value via
`use`: `val c = use state(0)` binds `c : State<i32>` (`c.value`, `c.set(n)`); the
`{value, set}` form also destructures — `val {value, set} = use state(0)`. A
binding never reuses the hook's name (`val r = use router()`, not `val router`).
Called **without** `use`, a hook is an ordinary call — the first-render value —
legal in any body; that is how the tests read the hooks.

## DOM builders & rendering

`text(value)` is an explicit text node; `fragment(children)` groups siblings
with no wrapper; `div`/`span`/`p`/`h1`/`ul`/`li` are element builders. Each takes
a `Children` argument, so the call site can pass a **list** (`div([a, b])`), a
single `Element`, or a `string` (the G4 coercion). The **list form is what V1
renders** (and what the `html` DSL emits); a lone-child / `string` argument
type-checks but its render is a recorded follow-up.

`renderToString(e)` serializes a tree to HTML, purely and synchronously:

{render_nested/src/main.bp}

**Every call spells `attrs:`, inner ones included.** The declared default
(`attrs: Array<#(string, string)> = []`) is part of every builder's signature,
but the compiler does not apply a declared parameter default at the call site
today, so omitting the argument is an arity error rather than an empty list.

## The element surface (`elements.bp`)

`element.bp` is frozen at eight constructors. `elements.bp` carries the rest of
the tag set in exactly the same shape, so a reader cannot tell from a call site
which of the two a tag came from:

```text
pub fn <tag>(children: Children, attrs: Array<#(string, string)> = []) -> Element
```

Children positional, `attrs:` labeled. The shape is not a free choice: the
`` html @`…` `` DSL writes `tag([kids], attrs: [pairs])`, so a constructor of any
other arity is unreachable from the markup front-end.

Two builders and two predicates:

| Function | What it is |
|---|---|
| `el(tag: string, children: Children, attrs: Array<#(string, string)>) -> Element` | The single place an ordinary element is built — and the **escape hatch** for a tag the surface does not name: `el("figure", kids, attrs: [])` |
| `voidEl(tag: string, attrs: Array<#(string, string)>) -> Element` | The same, for an element that cannot have children: it stores none |
| `isVoidTag(tag: string) -> bool` | The HTML spec's void-element list — `area`, `base`, `br`, `col`, `embed`, `hr`, `img`, `input`, `link`, `meta`, `param`, `source`, `track`, `wbr`. Written once here so a void-aware renderer consults it instead of restating it |
| `isRawTextTag(tag: string) -> bool` | `script` and `style` — the two elements whose text content is raw text and must **not** be HTML-escaped. `title` and `textarea` are *escapable* raw text, where escaping is correct, and are deliberately absent |

### The tags

| Group | Constructors |
|---|---|
| in `element.bp` (frozen) | `text`, `fragment`, `div`, `span`, `p`, `h1`, `ul`, `li` |
| sectioning and flow | `a`, `nav`, `section`, `article`, `header`, `footer`, `main`, `aside` |
| headings and text-level | `h2`, `h3`, `h4`, `h5`, `h6`, `label`, `timeTag` |
| forms | `form`, `button`, `select`, `option`, `textarea` |
| tables | `table`, `thead`, `tbody`, `tr`, `th`, `td` |
| document | `htmlTag`, `head`, `body`, `title`, `script`, `style` |
| **void** | `input`, `img`, `meta`, `link`, `br`, `hr` |

Anything else is `el("<tag>", children, attrs: [])`, or `voidEl("<tag>",
attrs: [])` when it cannot have children.

A void constructor keeps the same two-parameter shape and **drops** the
children it was handed — `input([text("x", attrs: [])], attrs: []).children` is
empty. The one-parameter `input(attrs:)` that would make children an arity
error was rejected: it is a second convention, and it is unreachable from the
`` html @`…` `` DSL's call shape.

### Three names that could not be the obvious one

| Tag | Constructor | Why |
|---|---|---|
| `<html>` | `htmlTag` | `html` is already the `` html @`…` `` template fn (member `rakun-bpp`), and a file importing the DSL beside the tags would bind two `html`s — a collision. The DSL keeps the name |
| `<time>` | `timeTag` | `time` was a std module when the tag was named (std's clock is `io.clock` since decision 106), and a consumer importing it in the same file would have collided |
| `<main>` | `main` | Shipped under its own name, because the consuming fronts import it that way |

**The `main` caveat.** A module that declares the program entry point `fn main()`
must not also `import {main} from "rakun-bpp"` in that same module. The remedy is
`el("main", children, attrs: [])`. Import aliasing is *not* a remedy: `import
{main as mainTag} from "rakun-bpp"` parses, but nothing outside the parser reads
the alias for a package import, so the binding still lands under `main`.

**Attribute values are stored verbatim.** A constructor never escapes: an `href`
of `/a&b` is kept as `/a&b`. Escaping happens once, at render, in the renderer
that emits HTML; doing it in the constructor as well would double-escape the
moment both layers are present, and a constructor cannot know whether its output
is bound for HTML, for a payload envelope, or for a test.

**`renderToString` is not void-aware.** It is `element.bp`'s in-repo test
renderer and writes a closing tag unconditionally, so
`renderToString(el("br", [], attrs: []))` answers `<br></br>`. That is why the
void set is *exported* rather than applied here: the renderer that ships reads
`isVoidTag`.

**A void element cannot be authored inside `` html @`…` ``.** The DSL lowers a
self-closing tag to a one-positional-argument call and flushes it after the
token loop rather than at its position, so `<div><img/></div>` renders
`<div></div><img></img>` — the image lands after its parent. Build void
elements with the constructor and interpolate the result. `<html>` in markup
is doubly unavailable: the tag would resolve to the DSL's own `html`.

## Client runtime

The client build resolves `rakun-bpp/hooks` to `rakun-bpp/client_runtime.mjs`
(`modules/rakun-bpp/src/client_runtime.mjs`, shipped next to the emitted modules
by `botopink build`): the same five nouns, the same signatures and shapes, over rakun-bpp's
own minimal render loop — cursor-indexed cells (the static-prefix rule is what
keeps the order stable), `set`/`dispatch` schedule one re-render per microtask,
effects run after commit when their `deps` change; `render(component, commit)`
drives a component and hands every committed tree to `commit`. Outside a render
every cell yields its first-render value, so the module is a drop-in for the
pure bodies. The substitution itself is the client bundler's step (front 68,
1.0.10-beta); under node it is a `require.cache` seed — `examples/rakun-bpp/jhonstart-
counter/client.mjs` runs the built `Counter` that way and prints the re-renders
after `set(3)` and `set(-2)`. `modules/rakun-bpp/src/client_runtime.bp` carries
the one bp-typed cell, `clientRender`, whose
`#[compiler.external(.JavaScript(\"require('./client_runtime.mjs').render(…)\"))]`
is what makes the CLI ship the sidecar (a miss is silent — see `AGENTS.md`
§ Known defect); the five nouns are not re-declared in
bp, because a package's import surface is flat and a second `state` would
shadow `hooks.state` for every consumer.
