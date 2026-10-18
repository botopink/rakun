# rakun-style

> Package `rakun-style` (was `styled`; front 165 s2) of the rakun workspace — `repository/rakun/modules/rakun-style/` · workspace rules: [`../../AGENTS.md`](../../AGENTS.md) · refusals: `../../refusals/rakun-style/` · examples: `../../examples/rakun-style/`

The `rakun-style` package (decision 338; its `` styled @`…` `` template function keeps its name): the base for building CSS components. `` styled @`…` `` and
`` styledProperty @`…` `` are template functions (over the template text, `expr css: string`) that read a CSS rule body at build and answer a
component in the language's model — `@Component<Styled>` (`StyledView`) and
`@Component<StyledProperty>` (`StyledPropertyView`); the layered `Sheet` holds
components in `@layer`s; the theme mechanism (`Theme`, `entry`, `clear`, `clearNs`, `clearAll`,
`extendTheme`, `#[theme]`) is what `@variant md` and `--theme(…)` read. The middle of the three
CSS layers: it imports `css` (the reader's character walk) and `std`, and knows no file kind, no
markup, no manifest and no framework.

```bp
import styled, {styledProperty, StyledView, StyledPropertyView} from "rakun-style";

pub val tab4 = styledProperty @`tab-size: 4;`;
fn padAll(n: i32) -> StyledPropertyView { return styledProperty @`padding: --spacing(${n});`; }

// `${padAll(2)}` is a call: computed at render, so a function run below the
// render's `StyledSheet` provider (a `val` is evaluated outside every render).
fn code() -> StyledView {
    return styled @`
  ${tab4}
  font-family: var(--font-mono);
  &:hover { ${padAll(2)} }
  @variant md { max-width: --theme(--breakpoint-md); }
`;
}
// (await code()).rules, under a provider ==
//   .s_<h>{tab-size:4;font-family:var(--font-mono)}.s_<h>:hover{padding:calc(var(--spacing) * 2)}
//   @media (width >= 48rem){.s_<h>{max-width:48rem}}
```

**A library of its own** (decision 326). A program that imports `from "rakun-style"` declares it in
`dependencies` (decision 242) — `{ "rakun-style": { "git": "https://github.com/botopink/rakun.git",
"branch": "feat" } }`; this package declares `css` the same way. Inside the meta checkout a
`git` entry resolves by name through the `repository/` root, elsewhere through the install store.

No `#[@external(…)]` cell of its own: the run-time half calls std's `hash.contentHash`, the build-time
half is pure botopink run on the comptime runtime (decision 331).

## Tree

> **In the rakun workspace** (front 165 s1) this package is `modules/rakun-style/`, and the tree below is the one it had as a repository of its own: its former `modules/*` are siblings in rakun's `modules/`, its cells are `conformance/styled/`, its examples `examples/styled/`, its refusals `refusals/styled/`; the root manifest, `scripts/` (one gate, one hook), `.github/` and `.gitignore` are rakun's — read the tree for the package's own layout, never for those.

```text
styled/
├── AGENTS.md
├── botopink.json      ← "name": "styled", "targets": ["erlang", "commonJS"], `files` = every src module, `css` in dependencies
├── src/
│   ├── root.bp        ← `pub mod` per module, a module before the siblings that import it; `styled` the default module
│   ├── hash.bp        ← classHash — djb2 over code points, std's contentHash in pure botopink (the build-time class)
│   ├── theme.bp       ← Theme, ThemeEntry, Ns, ThemeValue, ThemeChange, entry, clear, clearNs, clearAll, extendTheme,
│   │                    baseTheme, themeValue, wasCleared, valueText, nsPrefix, the #[theme] decorator
│   ├── variants.bp    ← VariantRead, readVariant — what `@variant <name>` means under a theme
│   ├── reader.bp      ← Source, Block, Value, readBlock, firstNonDeclaration — the literal read at build
│   ├── layers.bp      ← Layer, layer, SheetEntry, Sheet (of, add, classIn, render)
│   └── styled.bp      ← StyledSheet, styledContext, Styled, StyledProperty, StyledView, StyledPropertyView,
│                        Styleable, styled (default), styledProperty, the constant/computed constructors,
│                        splice, holeText, Holes (what a literal's holes are worth at build, decision 355)
├── test/              ← styled_test (the literals), theme_test, sheet_test, context_test (what registers through
│                        StyledSheet's context, the provider's writer a std mock), styled_example_test (front 119's
│                        example as a suite case, but for the import lines), source_order_test (the
│                        reader's source order, decision 368)
├── examples/styled-example/   ← front 119's example as an application of `from "rakun-style"`
├── examples/styled-context/   ← a render's root providing StyledSheet's context, its writer printing each registration;
│                                `expected.out` (the repository stage runs it)
├── examples/styled-context-unbound/ ← a computed literal with no provider: `before`, then context-unbound
│                                (`expected.out`, `expected.stderr`)
├── examples/styled-source-order/ ← decision 368's literal, its padding after the `:focus`: a constant of
│                                the emitted module, `expected.out` (the repository stage builds and runs it)
├── refusals/<case>/   ← a literal or annotation that must not compile, with its exact message
└── scripts/git-hooks/ ← pre-commit, lib/runner-standalone.sh (shared text), repository-stages.sh (styled's own)
```

## The literal

A rule body, read at build (`reader.bp`):

| Written | Served (`.k` = the component's class) |
|---|---|
| `prop: value;` (the `;` required) | `.k{prop:value;…}` — whitespace squeezed, comments dropped |
| `${p}` where a declaration stands (`p` a `StyledPropertyView`) | `p`'s declarations in place — Tailwind's `@apply` |
| `${v}` inside a value (`v` a `string`, `i32` or `f64`) | the value's text |
| `&:hover { … }`, `.icon { … }`, `a, & > p { … }` | `.k:hover{…}`, `.k .icon{…}` — CSS nesting, lists crossed |
| `@variant hover / first / after { … }` | the pseudo-class or pseudo-element appended |
| `@variant dark / print / motion-reduce { … }` | wrapped in the `@media` condition |
| `@variant md { … }`, `@variant max-md { … }` | `@media (width >= <--breakpoint-md>)`, `(width < …)`, from the theme |
| `@media`, `@supports`, `@container`, `@starting-style` `{ … }` | wrapped: `@media (…){.k{…}}` |
| `--spacing(n)`, `--alpha(c / p)`, `--theme(--name)` in a value | `calc(var(--spacing) * n)`, `color-mix(in oklab, c p, transparent)`, the theme's value |

Rules come out in source order (decision 368): each run of a block's declarations is a rule of
the block's selector, and each nested rule, variant or at-rule follows the run before it — a
declaration written after a nested rule opens a new rule of the class, as CSS Nesting's
nested-declarations rule does in a browser. `` styled @`${bg} &:focus { ${gray} } ${pad}` `` renders
`.k{background:#ffffff}.k:focus{…}.k{padding:…}`, never `.k{background:…;padding:…}.k:focus{…}`;
the class hashes the rules as rendered, so an order is a class (`reader.bp` `readBlock`, the
`run` it closes at each nested block; `test/source_order_test.bp`). Refused, each at
its character (`refusals/`): `@utility` (a `val` or a function names a component), `@theme` (the
typed `#[theme]`), `@apply` (a hole), `@custom-variant` (a variant is a function), any other
at-rule, `--value()` (a parameter), a declaration with no `;`, a value in `{ }`, a hole as a
property name or a selector, a breakpoint the theme cleared or lacks, an unclosed block, string
or comment; in `styledProperty`, any `{`, `&` or `@`.

**The class.** `s_` and std's `contentHash` of the rules (the class selector written `\u{1}`
while hashed), so the same rules are the same class. A literal with no hole is computed at build: `` styled @`color: red;` `` emits
`styledConstant("s_…", ".s_…{color:red}")`. A literal with a hole is computed when the component runs,
even when every hole is known at build (`` styled @`${tab4} color: red;` `` with
``tab4 = styledProperty @`tab-size: 4;` ``): the template parses the `${…}` holes from its raw text and
splices each hole's expression into the code it builds, and it never reads a hole's value (decisions
577 (5), 578). The computed literal's class is the same as a build-time one's for the same text
(`s_b480a37a`, `.s_b480a37a{tab-size:4;color:red}` for that example; `test/styled_test.bp`), and a
value that does not fit where it stands (a record in a value, a string where a declaration stands) is
refused by the computed call's types. The constant path emits `styledConstant("s_…", ".s_…{…}")` /
`propertyConstant(…)` with literals
(`hash.bp`'s fold, held equal to `contentHash`; `repository-stages.sh` reads the emitted module
on both targets — the call's arguments are the class and the rules as literals, no hidden context
argument (decision 388 replaced 354 (8)'s map; a component is a lambda over its `RenderScope`); it
also reads `code`'s computed call, its splice through `splice`). A literal with a hole (a
parameter, a call such as `${padAll(2)}`, a `val`, a splice) emits `styledComputed` /
`propertyComputed`, which build the text when the component runs (an `async function` on commonJS,
decision 338 p9).

**Registration** (decisions 352, 354, 378, 379). `pub val styledContext = createContext(StyledSheet(layer:
"", add: missingProvider))` declares `StyledSheet`'s default; a
`StyledSheet(layer, add)` is the render's sheet as a component sees it — the layer it writes to and
the writer of the sheet its provider holds. Whoever renders provides it at the root (rakun-bpp's
`compose`, emilia's `flush()`, the build's sheet at a prerender); `styled` holds no store and no
host cell. `styledComputed` and `propertyComputed` read it with `use context(StyledSheet)` at the
top of their bodies (357) and hand `add` their class and rules every time they run — the provider's
`Sheet.add` keeps a component once. A `${p}` splice registers nothing: the computed call takes each
splice as `splice({ -> <hole> })`, which runs the hole under a provider that keeps nothing. A
literal computed at build registers nothing (its constructor reads no context). With no provider
above, a computed literal reads the declared default, whose writer aborts naming the missing
provider (378 (3)) — so a `val` whose literal is computed
at render (`` pub val code = styled @`${padAll(2)}` ``) fails when it is first read, being evaluated
outside every render (`119-f`); such a component is a function.

**The sheet** is a value: `Sheet.of([layer("base"), Layer(name: "utilities", prefix: "e_")])`,
`sheet.add(layerName, styled)` answers the sheet with the component in that layer once, under the
layer's prefix (the hash kept), and `render()` writes `@layer <name>{…}` per non-empty layer in
declaration order.

## Testing

```sh
../botopink-lang/zig-out/bin/botopink test --target erlang
../botopink-lang/zig-out/bin/botopink test --target commonJS
../botopink-lang/zig-out/bin/botopink format --check src test examples refusals
```

`zig build test-libs` discovers the package as the cells `styled · erlang` and
`styled · commonJS`. Every expected text in the tests is a literal.

## Language notes (measured on the compiler this library landed on)

Each `// LANGUAGE GAP` marker names its row of the milestone's `language-gaps.md`.

- A function a template body reaches names no enum variant and builds no private record (the
  comptime runtime does not lower them): `reader.bp` and `variants.bp` carry kinds as strings
  and their records are `pub`. The run-time constructors are the template's emitted code, so
  they use enums freely.
- A library's template function cannot read the program's catalogue: both literals read
  `baseTheme()`, never the application's `#[theme]`, so a second `#[theme]` is not refused and a
  cleared breakpoint is refused only against the base theme (`119-d`).
- A template body cannot call a host function: the build-time class is `hash.bp`'s fold.
- A component's fields are read after `await` (`(await code()).rules`) — on commonJS a component
  call is a promise.
- A `val` initializer runs outside every render (erlang caches it on first read, commonJS at module
  load, a test module at its init), so a `val` holding a literal computed at render is
  `context-unbound` there and nothing refuses it at build (`119-f`).
- `botopink format` reflows a call inside a `${…}` hole of a multi-line literal over three lines;
  the code stays the same.
