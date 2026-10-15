# rakun-stylesheet — CSS from typed tokens

> Package: [`modules/rakun-stylesheet/`](../../modules/rakun-stylesheet/) · index: [`../docs.md`](../docs.md) · notes: [`../../modules/rakun-stylesheet/AGENTS.md`](../../modules/rakun-stylesheet/AGENTS.md)

rakun-stylesheet is the CSS-in-bp package of the rakun-bpp stack. You write
styles by **listing typed tokens**; each token becomes a CSS declaration, the
resulting body is hashed into a stable class name, and every class is collected
on a per-render `<style>` registry. The entry point keeps the name it had before
the package joined rakun: `emilia(tokens)` answers the class name, `flush()` the
stylesheet.

## Features

Each feature is a directory, `conformance/rakun-stylesheet/<feature>/`: its `docs.md`
says what the feature does and links the cells beside it.

| Feature | What it shows |
|---|---|
| [Getting started](getting-started/docs.md) | installing, the first style, the class on an element, your own utilities |
| [The reset](reset/docs.md) | the opt-in preflight |
| [Container queries](containers/docs.md) | `@container` builders |
| [Escape hatches](escape-hatches/docs.md) | arbitrary values and the deviations from upstream |
| [Typography](typography/docs.md) | `Text`, `Font`, `List` |
| [Colour](color/docs.md) | the palette, backgrounds, gradients, alpha |
| [Spacing](spacing/docs.md) | padding, margin and space between children |
| [Sizing](sizing/docs.md) | width, height and the named widths |
| [Layout](layout/docs.md) | `Layout`, `Flex`, `Grid`, `Gap`, `Table` |
| [Borders](borders/docs.md) | `Border`, `Outline`, `Ring`, `Divide` |
| [Effects](effects/docs.md) | shadows, opacity, blend, masks, filters, `Svg`, `A11y` |
| [Motion](motion/docs.md) | `Transition`, `Animate`, `Transform`, `Interact` |
| [Modifiers](modifiers/docs.md) | the variant table, groups and peers |
| [The theme](theme/docs.md) | `extendTheme`, spacing, the palette, a theme module |
| [The runtime and the output](output/docs.md) | `emilia(tokens)`, `flush()`, stable hashes, the cascade |

## The token enum

Every utility is a typed enum variant. Unknown variants are type errors
at the call site, not runtime fall-throughs. The full v0 surface (with
the values each variant emits) lives in
[`modules/rakun-stylesheet/src/tokens.bp`](../../modules/rakun-stylesheet/src/tokens.bp); each feature below lists its groups.

## What's coming (v0.beta.21+)

The spec authors a richer surface that v0 does not yet ship:

- `#[emilia([.Pad.All.4, .Bg.White])] div([…])` — annotation on
  builder, generic rakun-bpp hook.
- `<div [emilia]={[.Pad.All.4, .Bg.White]}>` — `[name]={expr}`
  attribute inside the `html """…"""` DSL, generic rakun-bpp hook.
- Nested section paths (`.Color.Red.500`, `.Pad.X.4`) — gated on the
  `enum-sections` language extension. v0's flat variant names
  (`ColorRed500`, `PadX4`) re-shape into the section paths when
  `enum-sections` lands.
- erlang/beam port for the `Stylesheet` host cell — same surface, swap
  the `Map` for `persistent_term` or an Agent.

The intent + the comptime expansion model live in the spec at
the meta repository's `specs/1.0.10-beta/05-emilia/README.md`;
the AGENTS.md tracks the deferred items and the maintainer rules.
