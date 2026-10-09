# styled

> Repository: `botopink/styled` (`git@github.com:botopink/styled.git`) · in the meta checkout: `repository/styled/`

The `styled` library (decision 338): the base for building CSS components. `styled "…"` and
`styledProperty "…"` are template functions that read a CSS rule body at build and answer a
component in the language's model — `@Component<StyledBase, Styled>` (`StyledView`) and
`@Component<StyledBase, StyledProperty>` (`StyledPropertyView`); the layered `Sheet` holds
components in `@layer`s; the theme mechanism (`Theme`, `entry`, `clear`, `clearNs`, `clearAll`,
`extendTheme`, `#[theme]`) is what `@variant md` and `--theme(…)` read. The middle of the three
CSS layers: it imports `css` (the reader's character walk) and `std`, and knows no file kind, no
markup, no manifest and no framework.

```bp
import styled, {styledProperty, StyledPropertyView} from "styled";

pub val tab4 = styledProperty "tab-size: 4;";
fn padAll(n: i32) -> StyledPropertyView { return styledProperty "padding: --spacing(${n});"; }

pub val code = styled """
  ${tab4}
  font-family: var(--font-mono);
  &:hover { ${padAll(2)} }
  @variant md { max-width: --theme(--breakpoint-md); }
""";
// (await code).rules ==
//   .s_<h>{tab-size:4;font-family:var(--font-mono)}.s_<h>:hover{padding:calc(var(--spacing) * 2)}
//   @media (width >= 48rem){.s_<h>{max-width:48rem}}
```

**A library of its own** (decision 326). A program that imports `from "styled"` declares it in
`dependencies` (decision 242) — `{ "styled": { "git": "https://github.com/botopink/styled.git",
"branch": "feat" } }`; this package declares `css` the same way. Inside the meta checkout a
`git` entry resolves by name through the `repository/` root, elsewhere through the install store.

No `#[@External]` cell of its own: the run-time half calls std's `hash.contentHash`, the build-time
half is pure botopink run on the comptime runtime (decision 331).

## Tree

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
│   └── styled.bp      ← StyledBase, Styled, StyledProperty, StyledView, StyledPropertyView, Styleable,
│                        styled (default), styledProperty, the constant/computed constructors, holeText
├── test/              ← styled_test (the literals), theme_test, sheet_test, styled_example_test (front 119's
│                        example as a suite case, but for the import line)
├── examples/styled-example/   ← front 119's example as an application of `from "styled"`
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

Rules come out in order: the block's own declarations, then its nested rules. Refused, each at
its character (`refusals/`): `@utility` (a `val` or a function names a component), `@theme` (the
typed `#[theme]`), `@apply` (a hole), `@custom-variant` (a variant is a function), any other
at-rule, `--value()` (a parameter), a declaration with no `;`, a value in `{ }`, a hole as a
property name or a selector, a breakpoint the theme cleared or lacks, an unclosed block, string
or comment; in `styledProperty`, any `{`, `&` or `@`.

**The class.** `s_` and std's `contentHash` of the rules (the class selector written `\u{1}`
while hashed), so the same rules are the same class. A literal with no hole is computed at build:
the template emits `styledConstant("s_…", ".s_…{…}")` / `propertyConstant(…)` with literals
(`hash.bp`'s fold, held equal to `contentHash`; `repository-stages.sh` reads the emitted module
on both targets). A literal with holes emits `styledComputed` / `propertyComputed`, which build
the text when the component runs (an `async function` on commonJS, decision 338 p9).

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
- A template body cannot call a host function: the build-time class is `hash.bp`'s fold.
- A component's fields are read after `await` (`(await code).rules`) — on commonJS a component
  call is a promise.
- `botopink format` reflows a call inside a `${…}` hole of a multi-line literal over three lines;
  the code stays the same.

## Local gate

`scripts/git-hooks/pre-commit` is the tracked pre-commit gate, self-contained:
it sources `scripts/git-hooks/lib/runner-standalone.sh` from this repository and
reaches nothing outside it, so a standalone clone, a checkout inside the botopink
meta workspace and a worktree run the same gate. Install it once per clone:

```sh
git config core.hooksPath scripts/git-hooks
```

The repository is one plain package, so the gate's test stage runs
`botopink test --target <t>` at the root on each target `botopink.json` declares
(`erlang`, `commonJS`); `scripts/git-hooks/repository-stages.sh` adds styled's own
stage (the build-time class), `examples/*/` are built and `refusals/*/` refused.
Never commit with `--no-verify`; fix the red instead.
`scripts/git-hooks/pre-commit` and `scripts/git-hooks/lib/runner-standalone.sh`
are one text across every library repository: the meta repository's
`hook-integrity` workflow compares the bytes (its check 4), so a change to either
lands in all of them together. CI: `.github/workflows/test.yml` runs the same
package on linux and macos, on each declared target, with the compiler built from
`botopink/botopink-lang` `feat` and `css` checked out beside it. The organisation's Actions
policy is the maintainer's setting: until it admits this repository, the workflow does not run
here and the local gate and the meta checkout's `zig build test-libs` are the only verdicts.
