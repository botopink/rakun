# emilia · CHANGELOG

## Unreleased — v0.beta.22

- **The class is `e_` + `contentHash` of its rules** (1.0.12-beta
  `06-emilia/34` step 5, decision 367). `styleRule` hashes `classRules(sheet)`
  — the class's rules as the document writes them, the class written
  `\u{1}`, the text `styled` hashes for a component — instead of the codec
  payload, which the cell still stores. Every class name moves once; no CSS
  byte does. Contract 4's shared fixture is `e_f51c2501` (was `e_39b87d03`),
  `emilia-card`'s classes `e_13df5d57` / `e_41222bb0` / `e_bcdc3f6a`.
- **The open `05-emilia` rows, each measured against Tailwind 4.3.2's
  compiled output.**
  - `scale-*` writes upstream's `--tw-scale-{x,y,z}` percentages and
    `scale:var(--tw-scale-x) var(--tw-scale-y)`, registered with `@property`
    (initial `1`), so `ScaleX` and `ScaleY` compose; `scale:.5` /
    `scale:.5 1` are gone.
  - Every fraction is `calc(N / D * 100%)` through one `fraction(n, d)` —
    `Size.*.Frac`, `Inset.*.Frac`, `Flex.Basis.Frac` and the `Half` translates
    moved together, so the library keeps one convention.
  - `open:` / `group-open:` carry the legacy `[open]` attribute
    (`&:is([open], :popover-open, :open)`); `rtl:` / `ltr:` are v4.1's
    `&:where(:dir(rtl), [dir="rtl"], [dir="rtl"] *)`; `marker:` and
    `selection:` reach the element itself as well as its descendants — a list
    of one-`&` variants (`markerVariants()`, `selectionVariants()`), wrapped
    once each by `nestVariants`.
  - `spacingNegHalf(n)` spells the negative half steps; every `*.Neg.Half`
    gains `0` (`-mt-0.5`), and `spacingHalf` refuses a negative whole part.
  - The front-54 refusal of an entry in no namespace is asserted by its
    message rather than by the entry's absence.
  - Unconfirmed columns confirmed: the four interpolated grid/order sets, the
    `--ease-*` values, the `--font-*` stacks (now upstream's `theme.css`), the
    nine mask leaves, `indent-*`. The confirmation moved `opacity-*` to
    upstream's percentage (`opacity:60%`), negative rotations to
    `calc(Ndeg * -1)`, `rawShadow` to `--tw-shadow` + the five-channel reader,
    and `rawTransitionProperty` to the presets' three declarations.
  - The `??`-with-a-dummy-record reads are `if (x == null)` guards; a test
    helper that finds no rule panics instead of answering a blank `Rule`.

- **Translate and skew take upstream v4's form, and compose** (front 45,
  measured against Tailwind 4.3.2's compiled output). A translate axis writes
  `--tw-translate-<axis>` and `translate:var(--tw-translate-x)
  var(--tw-translate-y)`; a skew axis writes `--tw-skew-<axis>` and the
  five-variable `transform` chain; `transform-cpu` / `-gpu` are the chain rows.
  The variables are registered as `@property` blocks and the flush writes
  upstream's `properties` layer fallback (`output.bp`). The old rows (the other
  axis as `var(--tw-translate-y, 0)`, `transform:skewX(…)`, `§ 16.7`'s v3 chain)
  did not compose. `emilia` 724 → 728.

- **`Transform.Translate` — both axes** (front 45, from the track-D audit):
  `.Transform.Translate.{0,Px,1,Half,Full}` is `translate:<v> <v>`. The
  sub-dispatchers of fronts 41 and 45 take `th: Theme` like every other front's.
  `emilia` 723 → 724.

- **`space-*` and `divide-*` take upstream's form** (fronts 35 and 40, from the
  track-D audit). The child selector is `:where(& > :not(:last-child))` (no added
  specificity) and both sides of the gap are written through the reverse flag,
  so `XReverse` / `YReverse` finally move it; `emilia-spacing` and
  `emilia-outline-ring` updated.

- **Rings and shadows compose, and a lone ring renders** (fronts 40 and 41,
  from the track-D audit). Every ring and shadow token writes one channel of
  upstream v4's five-channel `box-shadow` reader, each channel with a null
  shadow as its fallback. The old ring listed three channels with no fallback —
  invalid at computed-value time unless all three were set — and `Effect.Shadow`
  wrote `box-shadow` itself, so the two overwrote each other. `emilia` 722 → 723.

- **The class slot — `attributes.bp`** (1.0.10-beta front
  `48-emilia-attributes`). `className` / `styled` / `styledWith` / `cls` /
  `clsWith` over one `Theme`, the static-first `mergeClass`, the ASCII gate, and
  contract 4's shared fixture (`e_39b87d03`). The ident and length reject sets of
  front 57 no longer scan with `split("")`, which drops non-ASCII text on
  erlang. `emilia` 711 → 722 on commonJS and erlang.

- **Custom utilities and variants — `compose.bp`** (1.0.10-beta front
  `59-emilia-custom-utilities-and-variants`). Bundles as `Token[]` functions,
  `compose`, `hocus` / `selector` / `themeMidnight`, and `named(class, tokens)`
  in `@layer components` (refusing `e_`, a bad ident and a duplicate). `emilia`
  697 → 709 on commonJS and erlang.

- **Container queries — `container.bp`** (1.0.10-beta front
  `58-emilia-container-queries`). `.Container.{Inline,Normal,Size}`,
  `containerName(name)` and the thirteen `containerAt<Size>(inner)` builders plus
  `containerNamed`; widths come from the theme's `--container-*`, and an
  undefined one panics. `emilia` 683 → 697 on commonJS and erlang.

- **Arbitrary values — `arbitrary.bp`** (1.0.10-beta front
  `57-emilia-escape-hatches`). Six top-level variants (`Arb`, `ArbProp`,
  `ArbVariant`, `ArbAt`, `ArbMin`, `ArbMax`) built through validating builders;
  a payload that could break out of its rule or the `<style>` element is refused
  at comptime (five template validators) and at run time (the builders and the
  dispatcher), never escaped. `emilia` 666 → 683 on commonJS and erlang.

- **`fullTheme()`, `fullOptions()` and `styleRule()`** (1.0.10-beta front
  `56-emilia-cascade-and-output`, decision 80). `flush()` now renders under
  `fullTheme()` — `defaultTheme()` extended by the palette, typography,
  effect, filter, transition and transform entries — so no `var(--…)` a token
  emits is left undefined; a test reads every theme reference out of a flushed
  document and fails on one the theme does not define. Front 41 gains the
  `effectEntries()` it never shipped (`--inset-shadow-*` without upstream's
  leading `inset`, which `InsetShadow` writes itself; `--text-shadow-*`).
  `styleRule(tokens, th)` is `emiliaWith` without the registration. The codec
  separator check now walks every front's leaf list. `emilia` 661 → 666.

- **`preflight.bp` added — the reset of `§ 4`** (1.0.10-beta front
  `55-emilia-preflight`). `preflightRules()` (eleven `base`-layer rules) and
  `preflight()` (the same as a CSS fragment); opt-in through
  `withBase(o, preflightRules())` only. `emilia` 644 → 661 on commonJS and
  erlang.

- **`Svg` and `A11y` added — `§ 18`, `§ 19`** (1.0.10-beta front
  `47-emilia-svg-accessibility`). 11 leaves plus `SvgFill` / `SvgStroke` /
  `SvgStrokeWidthRaw` and their wrappers. `sr-only` / `not-sr-only` carry
  upstream's bodies, read from `utilities.ts` because the reference prints none.
  `emilia` 633 → 643 on commonJS and erlang.

- **`Interact` added — `§ 17`** (1.0.10-beta front `46-emilia-interactivity`).
  161 leaves plus `InteractAccent` / `InteractCaret` / `InteractScrollbarColor`
  and the wrappers `accent` / `caret` / `scrollbarColor`, every colour a
  `paletteVar` reference and every scroll offset `spacing(n)`. `Snap.Type`
  reads the strictness with `proximity` as its fallback, since `--tw-*` cannot
  be a theme entry. `emilia` 608 → 633 on commonJS and erlang.

- **`Table` added — `§ 14`** (1.0.10-beta front `43-emilia-tables`). 21 leaves
  over `border-collapse`, `table-layout`, `border-spacing` (front 54's
  `spacing(n)`, no resolved length) and `caption-side`, plus `TableSpacingRaw`
  and `rawTableSpacing`. `emilia` 598 → 608 on commonJS and erlang.

- **`Filter` and `BackdropFilter` added — `§ 13`** (1.0.10-beta front
  `42-emilia-filters`). 108 leaves in two sections plus the top-level
  `FilterRaw` / `BackdropRaw` and the wrappers `rawFilter` / `rawBackdropFilter`.
  Every leaf but `Blur.None` writes its family's `--tw-*` custom property and one
  reader of all the families with empty fallbacks, so filters compose instead of
  the last one winning. The backdrop section is `BackdropFilter` because
  `Backdrop` is the `::backdrop` modifier. `filterEntries()` carries the
  `--blur-*` / `--drop-shadow-*` values. `emilia` 569 → 598 on commonJS and
  erlang.

- **Front 24 — effects by return type** (botopink decisions 118 and 120). The
  `#[@future]` annotation leaves: `drainRules`, `flushWith` and `flush` are
  `-> Task<string>`, and the eight examples' `main` is `fn main() -> Task<void>`.
  None of them can fail, so no `Result` enters the Task and every `await` stays a
  bare `await` (no `try await`). The comments and `AGENTS.md` name the Task and the
  `test` block's implicit await channel instead of the future context.
  Measured against botopink-lang `front/24-effects-by-return` `86609a66`: every
  emilia row at its pre-sweep count on commonJS and erlang (`emilia` 569/569, the
  sixteen members unchanged).

- **Front 95 — the `emilia-test` member.** `modules/emilia-test/` is created
  with an empty `pub` surface and one inline test (the core resolves from it,
  1/1 on commonJS and erlang), `emilia` as `{ "workspace": true }`. It is where
  the track-D `assert<Subject>(loc, …)` snapshot helpers land; nothing else in
  the workspace changes.

- **`Transform` added — the whole of `§ 16`** (1.0.10-beta front
  `45-emilia-transforms`). 96 leaves in one section of sixteen sub-sections,
  plus the two top-level variants `TransformRotateRaw` and
  `TransformTranslateRaw`.

  **Front 44 could animate a property nothing could set.** `Transition.Transform`
  emits `transition-property:transform`, and until this front there was no
  `rotate`, no `scale`, no `translate`, no `skew`, no `transform-origin`, no
  `perspective` and no `backface-visibility` anywhere in the library. A card
  that lifts under the pointer, a chevron that flips when a disclosure opens, a
  toast that slides in and a modal that scales in are all one property.

  **In v4 `rotate`, `scale` and `translate` are independent CSS properties**,
  not `transform` functions, so three tokens in one list are three declarations
  in one rule and none overwrites another. No `--tw-*` cascade is needed to
  compose them, and the pre-1.0.10 `transform:rotate(45deg) scale(1.1)` shape is
  superseded wholesale.

  **No leaf resolves a length.** `translate-x-1` is front 54's `spacing(1)` and
  the five perspective keywords are `--perspective-*` references, so the
  `100px` … `1200px` the reference prints in parentheses are theme entries in
  the new `transformEntries()`. Unlike front 44's three `--ease-*`, **none of
  the five values is provisional** — `§ 16.2` prints each one. The two
  exceptions to the length rule are `TranslateX.Px` and `TranslateY.Px`, whose
  `1px` is the reference's own literal value.

  **Three rows of `§ 16` did not survive, and each is flagged where it is
  emitted:**

  - `§ 16.6`'s property column says `skew-x: 3deg`, which is not a registered
    CSS property. The upstream page was checked, as the front's own spec
    demanded, and prints `transform: skewX(3deg)`; the twelve skew leaves emit
    **upstream's** property and the reference file's spelling is asserted
    absent.
  - `§ 16.10`'s rows are ONE `translate:` declaration reading the other axis's
    `--tw-translate-*` variable — which is what the reference file **and**
    upstream both print. The variable's `@property` default cannot be a theme
    entry (`--tw-` is in none of the nineteen namespaces and `extendTheme`
    refuses it), so it is carried as `var(--tw-translate-y, 0)` through front
    39's `cssVarOr`. **The two axes therefore do not compose** — two
    declarations of one property, last one wins; `rawTranslate("50% 50%")` is
    the diagonal.
  - `§ 16.7`'s four `transform` rows are transcribed **verbatim and inert**.
    They read six `--tw-*` variables no token in emilia sets. Fallbacks would be
    worse than the flag: `.Shorthand.Cpu` would emit an identity transform that
    silently overwrote the `skewX` beside it.

  `scale-50` emits `.5` and `zoom-50` emits `0.5`, four subsections apart in the
  same section; both are the reference's and the two are asserted in adjacent
  lines. `Neg` is a sub-section and not a sign, because there is no spelling for
  a negative numeric leaf. `Style.Preserve3d` is named after the value it emits,
  because a leaf cannot begin with a digit and the class is `transform-3d`.

  Four planted defects were watched redden and removed, one of them in the
  class-fragment probe itself: `var(--tw-scale-x)` contains `scale-x`, so the
  bare stems fired on `§ 16.7`'s composed rows and every fragment now carries
  its suffix.

  `examples/emilia-transforms/` is the new worked example (18 tests).
  `modules/emilia` goes from 528 to **569** inline tests, green on commonJS and
  on erlang.

- **`Transition` and `Animate` added — the whole of `§ 15`** (1.0.10-beta front
  `44-emilia-transitions`). 36 leaves, and the first front whose output is not
  only a declaration list.

  **Every state emilia could express arrived in one frame.** Front 34 shipped
  83 modifiers — `Hover`, `Focus`, `Active`, `Open`, `Disabled` and the rest —
  and there was no `transition`, no `duration`, no timing function and no
  `delay` anywhere in the library, so a button that darkens on hover darkened
  between two frames with nothing in between. There was also no `animate-spin`,
  so a loading state had no token at all and needed a hand-written stylesheet
  beside emilia in the same codebase.

  `Transition` carries the seven rows of `§ 15.1` — six of them **three
  declarations from one token**, which `tokensToCss`'s `;`-join already
  supports — plus `Behavior` (`§ 15.2`), the nine-step `Duration` and `Delay`
  ladders (`§ 15.3`, `§ 15.5`) and the four `Ease` leaves (`§ 15.4`). `Animate`
  is `§ 15.6`'s five.

  **`.Transition.Base`, not `.Transition.Default`.** Two reasons at once:
  `default` is in the lexer's keyword table, and `Default(inner)` is already a
  top-level modifier variant — the exact collision the section-head audit
  exists to catch.

  **`transition-discrete` emits `allow-discrete`.** The class name and the CSS
  value do not match; it has a test of its own, asserted in both directions.

  **Every duration and delay step carries `ms`, `0ms` included.** A bare `0` is
  legal CSS for a length and is not what the reference prints. Neither ladder is
  a theme lookup, and that is the reference's call: `§ 15.3` and `§ 15.5` print
  the milliseconds literally and upstream has no `--duration-*` namespace.

  **The space after each comma in the property lists is the reference's and is
  counted as well as spelled.** `color, background-color, …`; a test asserts
  eleven properties and ten `, ` separators, so a whitespace normaliser fails a
  test rather than changing the output quietly.

  **`animateTokenToSheet` is the one dispatcher in fronts 41–47 that answers a
  `Sheet`.** `animate-spin` is half a rule — the other half is `@keyframes spin`,
  which is not a style rule and cannot be nested inside one. Front 56's
  `blockSheet` carries it, `renderDocument` hoists it out of every cascade layer
  to the end of the document, and `dedupeBlocks` makes two spinners on a page
  one block.

  **The four keyframes bodies are read out of the theme, not transcribed.**
  The front README opens a gate — read the upstream page, paste the four bodies
  into the dispatcher, tick a `TODO.md` checkbox — that **front 54 had already
  closed**: `theme.bp`'s `animateEntries()` and `keyframeEntries()` carry the
  four `--animate-*` entries and the four bodies, inside `defaultTheme()`, and
  `renderDocument` already hoists them. So `animationSheet(th, name)` looks the
  body up through `keyframeCss(th)` instead of pasting a second copy beside it —
  a second transcription of one table is how two tables drift. The consequence
  is asserted: under a theme carrying no body for a name, the token still emits
  its declaration and hoists **no** block, which is also what makes
  `.Animate.None` and `AnimateRaw` blockless without a special case.

  **`transitionEntries()` — three `--ease-*` theme entries, PROVISIONAL, marked
  at the declaration.** `defaultTheme()` carries the four `--animate-*` and no
  `--ease-*`, so a project composes `extendTheme(defaultTheme(),
  transitionEntries())`. `§ 15.4` prints the three *names* and no value for any
  of them, and `§ 21` has no `--ease-*` table; the cubic-beziers come from the
  1.0.8-beta draft this front replaces. What is **not** provisional: the three
  names are the reference's verbatim, the namespace is front 54's `Ns.Ease`, and
  the shape is a single timing function — so replacing the values later moves
  nothing else, because every rule names the variable and never its value.

  **Two top-level arbitrary-value variants** — `TransitionProperty(value)` and
  `AnimateRaw(value)`, with the wrappers `rawTransitionProperty` / `rawAnimate`.
  Top-level for front 41's reason (a payload leaf inside a section cannot be
  constructed by any spelling), and for `AnimateRaw` that is not an
  inconvenience but a door: it is the only way to name an animation emilia does
  not ship. `rawAnimate` goes through `declSheet` and not through
  `animateTokenToSheet` — a custom animation names keyframes this front does not
  own, so it hoists no block. **PROVISIONAL as a pair**: `§ 15` prints no
  arbitrary-value row anywhere. The property each one sets is not.

  **The head audit found no collision and was run, not reasoned about.** Six
  heads — `Transition`, `Animate`, `Behavior`, `Duration`, `Ease`, `Delay` —
  against the 87 top-level payload variants and the keyword table. Four LEAVES
  repeat a head declared elsewhere (`Transition.All` beside `Pad.All` and
  `Gap.All`, `Transition.Opacity` and `Transition.Shadow` beside
  `Effect.Opacity` and `Effect.Shadow`) and each of the four is asserted to
  declare its own property with the other section's leaf asserted beside it, on
  both targets.

  **The walk over all 36 leaves** asserts the declaration carries a `:`; carries
  neither `cubic-bezier(` nor `infinite`; carries no Tailwind class fragment;
  and, for the two ms ladders, ends in `ms`. Each probe has a control that must
  fail and a control proving it does **not** fire on correct output —
  `var(--animate-spin)` contains the class name `animate-spin` and
  `var(--ease-in-out)` contains `ease-in-out`, so neither is in the fragment
  list and both are asserted not to trip it. The walk reads declarations and not
  sheets, deliberately: the `@keyframes bounce` body legitimately carries
  `cubic-bezier(0.8,0,1,1)`, and it is a block.

  `examples/emilia-transitions/` is the worked example (14 in-file tests): the
  catalogue, the preset-then-override ordering as working code, and a submit
  button whose colours move over 200ms on hover and which dims and grows a
  spinner while the form is in flight.

  **Where the spec and the tree disagree**, recorded rather than worked around:
  the `Owns:` line says `repository/emilia/src/…` and
  `repository/emilia/test/transitions_test.bp`, and the tree is a workspace with
  no `test/` directory — `modules.md`'s amendment says so and this front follows
  eleven landed fronts instead. The spec's Step 4 says `animateTokenToSheet` is
  "exhaustive over six leaves" and the section has five; the sixth it counts is
  `AnimateRaw`, which the same step routes through `declSheet` and which never
  reaches that `case`. Numeric leaves are written `__N` in expression position
  (`.Transition.Duration.__300`), not the spec's bare `.300`.

  33 tests in `emilia.bp` and 14 in the example; **528/528 on commonJS and on
  erlang** (6 + 37 + 45 + 440).

- **`Effect` corrected and widened; `Blend` and `Mask` added — the whole of
  `§ 12`** (1.0.10-beta front `41-emilia-effects`). 102 leaves, and the only
  front so far whose main job was to fix output emilia had already shipped.

  **`.Effect.Shadow.Sm`/`.Md`/`.Lg`/`.Xl` emitted `box-shadow:sm`,
  `box-shadow:md`, `box-shadow:lg` and `box-shadow:xl`** — the Tailwind class
  suffix in the position a CSS value belongs. No browser accepts any of them,
  so a page that asked for a shadow rendered flat, and the one assertion in the
  suite that touched the family pinned the wrong string. The four leaf NAMES
  are unchanged, so nothing that compiled before stops compiling; the four
  values are now `var(--shadow-sm)` and friends, which is what the reference's
  "Propriedade CSS" column prints. Both facts are asserted — the value each
  leaf has, and the value it must never have again.

  `Effect.Shadow` gains `X2xs`, `Xs`, `X2xl`, `None` and `Inner`;
  `Effect.InsetShadow` and `Effect.TextShadow` are new sub-sections;
  `Effect.Opacity` widens from five steps to twenty-one. `Blend` is
  `mix-blend-mode` and `background-blend-mode` over the same seventeen values
  (`§ 12.5` says so in one sentence, which is why they are two sub-sections of
  one section). `Mask` is `§ 12.6`'s nine properties, one sub-section each.

  **An inset shadow is not a longhand.** CSS has no `inset-box-shadow`; the
  property is `box-shadow` and `inset` leads the value, so
  `.Effect.InsetShadow.Sm` and `.Effect.Shadow.Sm` set the same property and
  the later token in a list wins.

  **No leaf resolves a shadow value, with exactly one exception that is
  asserted from both sides.** The three scales are `themeVar(…)` lookups over
  front 54's `--shadow-*`, `--inset-shadow-*` and `--text-shadow-*`, so a
  project that redefines a step moves every rule and not one byte of any rule
  body. `Shadow.Inner` is the exception: upstream has no `--shadow-inner` and
  `§ 12.1` prints its value inline, so it is a literal, and the walk asserts
  both that every other leaf is free of one AND that this one carries it. The
  front README's "no `rgb(` anywhere in this front's block" bullet contradicts
  its own table row and is wrong about it.

  **There is no `Ns.TextShadow`.** Front 54's nineteen namespaces do not
  include `--text-shadow-`, so `textShadowVar` spells the prefix literally and
  a project's `--text-shadow-*` entries are accepted under the `--text-`
  prefix — they read back through `namespace(th, Ns.Text)` and would be
  dropped by `clearNamespace(th, Ns.Text)`. Pinned by a test, with
  `--inset-shadow-*` as the control that shows the difference. A real
  `Ns.TextShadow` is front 54's to add.

  **Three top-level arbitrary-value variants** — `EffectShadowRaw(value)`,
  `EffectTextShadowRaw(value)` and `MaskImageRaw(value)`, with the wrappers
  `rawShadow` / `rawTextShadow` / `rawMaskImage`. They are top-level and not
  `Effect.Shadow.Raw(…)` because a payload leaf nested inside an enum section
  cannot be constructed by any spelling, and they are reached through wrappers
  because a leading-dot path followed by a payload call does not carry the
  typed-array context either. Both gaps were re-measured against compiler
  `2e6bb4ac` rather than taken from the spec, and one of the two diagnostics
  has changed — see `docs.md` § `Color.Hex("#abc")` is declared and
  unconstructible.

  **Marked PROVISIONAL at the arm that emits them**, not only in a table:
  six opacity steps (`15`, `35`, `45`, `55`, `65`, `85`), four `mask-position`
  keywords, four `mask-repeat` keywords, `mask-size:auto`, and the three
  arbitrary-value wrappers. `§ 12.3` prints fifteen opacity rows and `§ 12.6`
  twenty mask rows; the reference prints no arbitrary-value form anywhere.
  What is NOT provisional about each is stated beside it.

  102 leaves walked for well-formedness, for a bare Tailwind scale step as a
  value, and for a class fragment. Each probe carries a control that must fail
  AND a control proving it does not fire on correct output — `var(--shadow-sm)`
  legitimately contains `shadow-sm`, so the scale probe anchors on the colon.
  Three defects were planted, watched redden and removed; the first reddened
  eleven cells across three fronts.

  `Blend`'s two seventeen-value tables are written twice, because two enum
  types cannot share a `case`; a test strips the property name off each side
  and asserts the values are equal, in order.

  **Not declared:** `shadow-<color>/<opacity>`. `§ 12.1` gives the class and
  the prose and no property/value pair. Front 56's `Rule.declarations` makes
  the two-step protocol expressible, so the mechanism is no longer missing —
  the value is, and it reopens the moment the reference carries a row.

  `examples/emilia-effects/` is the worked example (12 tests).
  463 → **495** tests in `modules/emilia`, green on commonJS and on erlang.

- **`Text` and `Font` widened, `List` added — the whole of `§ 9`** (1.0.10-beta
  front `38-emilia-typography`). 437 leaves over thirty-two property groups, of
  which emilia covered four, partially, and three of those four emitted CSS that
  is not what Tailwind v4.3 emits. `Text` goes from eight leaves and eight sizes
  to five more bare leaves and seventeen sub-sections — Size (thirteen),
  Tracking, Leading, Clamp, Transform, Overflow, Wrap,
  Decoration { Style, Thickness, Offset, Color }, Whitespace, Break,
  OverflowWrap, Hyphens, Indent, Align, Tab and Content. `Font` gains four
  weights and four sub-sections — Smoothing, Style, Stretch and Nums. `List` is
  a new TOP-LEVEL section: `list-style-*` applies to the list and not to its
  text.

  **Four things changed meaning for paths that already compiled**, each because
  what they emitted was not what upstream emits. `.Text.Size.*` was
  `font-size:1.125rem` and is now the `var(--text-lg)` PAIR with its
  `--text-lg--line-height`: a `text-lg` in Tailwind changes leading, and in
  emilia it did not (`§ 9.2`). `.Font.{Sans,Serif,Mono}` spelled a literal
  family stack and now reference `var(--font-*)` (`§ 9.1`) — the stacks moved
  into `typographyEntries()`, so no value was lost. `.Text.Underline` and
  `.Text.LineThrough` emitted the `text-decoration` SHORTHAND and now emit
  `text-decoration-line` (`§ 9.17`), which is what makes `underline` compose
  with `decoration-dotted` instead of overwriting it. **`.Text.Bold` is
  untouched** — `font-weight:bold` is emilia's own leaf, not a transcription of
  a utility, and an explicit regression test says so beside the three that
  changed.

  That size change deleted **the library's last resolved `rem`**, and with it
  the walk CONTROL of four other fronts: 36, 37, 39 and 40 each assert "no leaf
  of this front resolves a length" beside a control asserting some real token
  DOES, and all four had chosen `.Text.Size.Lg` after front 40 took
  `.Border.Rounded.Lg` away from them. There is no such token any more, so all
  four controls are now hand-built declarations, each paired with the same fact
  asserted from the other side (`tokenDeclarations(.Text.Size.Lg)` carries no
  `rem`). Three more pinned strings moved with it — front 34's end-to-end
  button, front 56's leaf and mixed-token goldens — plus `examples/emilia-card`
  and `examples/emilia-backgrounds`, and `examples/emilia-modifiers`'s
  `text-decoration:underline`.

  **This front holds no colour table and no length ladder.**
  `Text.Decoration.Color` is front 33's 26 x 11 grid through `paletteVar`, so a
  decoration colour and a text colour reference ONE custom property and cannot
  drift; `Text.Indent` answers front 54's `spacing(n)`, the same function
  `.Pad.All.8` answers; `Text.Size`, `Tracking` and `Leading` answer front 54's
  `--text-*` / `--tracking-*` / `--leading-*` namespaces. `typographyEntries()`
  contributes the half of the theme the reference prints and `defaultTheme()`
  does not — the nine `--font-weight-*`, the six `--tracking-*` and the five
  `--leading-*` — and deliberately does NOT restate `--text-*`, which front 54
  already carries with the values `§ 21.3` prints.

  **Three theme rows are PROVISIONAL and say so at the declaration**, not only
  in a table: `--font-sans`, `--font-serif` and `--font-mono` carry no value
  anywhere in the reference (`§ 9.1` prints the reference form, `§ 21.3` only
  the size scale), so they carry emilia's own pre-38 stacks, moved verbatim out
  of the dispatcher. They are shorter than upstream's real defaults and must be
  confirmed before anyone reads them as v4.3 parity. `text-indent`'s
  `calc(var(--spacing) * N)` shape is the second: `§ 9.25` prints `indent-8` as
  HTML with no CSS, so the form is inferred from `§ 21.2` — what is not
  provisional is that it goes through `spacing(n)`.

  437 leaves walked for a resolved size, a colour, a font stack, a raw tracking
  or leading value, well-formedness and a Tailwind class fragment, each probe
  with a control that FAILS — and the class-fragment probe is asserted NOT to
  fire on correct output, because `var(--tracking-tight)` legitimately contains
  the string `tracking-tight`. Two planted defects were watched redden and
  removed. `examples/emilia-typography/` (11 tests) and
  `examples/emilia-text-decoration/` (11 tests) are the showcases. +44 inline
  tests in `modules/emilia`, which is **463** on commonJS and on erlang.
  **Reference gaps left undeclared**: `font-feature-settings`,
  `list-image-[url(…)]`, `content-['Hello']`, the numeric `leading-3`…`10`
  ladder (`§ 9.11` prints only the named values) and the `8` step on decoration
  thickness and underline offset (`§ 9.20` and `§ 9.21` stop at `4`) — the
  first three are the escape-hatch front's.

- **`Border` widened, and `Outline` / `Ring` / `Divide` added** (1.0.10-beta
  front `40-emilia-borders`). The whole of `§ 11`, 1704 leaves, in four
  families. `Border.W` gains the fifth width and eight directional
  sub-sections — an AXIS is two declarations, a SIDE is one, and `S`/`E` are
  `border-inline-start-width`/`-end-width`, which follow the writing direction
  where `L`/`R` do not. `Border.Style` is new: a dashed or dotted border was
  inexpressible. `Border.Rounded` goes from four leaves to a ten-leaf ladder on
  the shorthand AND on fourteen directional sub-sections — the four sides, the
  four physical corners and the six logical ones — so a card with a rounded top
  and a square bottom can finally be described.

  **Two things changed meaning for paths that already compiled.**
  `.Border.Color.<family>.<shade>` used to emit `border-color:red` for every
  cell: the shade level existed in the type and did nothing, so three shades of
  one family were ONE class, because the class name hashes the body. It now
  emits the palette reference. And `.Border.Rounded.{Sm,Md,Lg}` used to resolve
  a literal `rem` and now reference `var(--radius-*)`, so a project that
  overrides `--radius-lg` moves every rounded corner with it. `Full` and `None`
  do not change — upstream prints `rounded-full` as `9999px` and `rounded-none`
  as `0`, and neither is a theme entry.

  That second change cost three OTHER fronts their walk control. Fronts 36, 37
  and 39 each assert "no leaf of this front resolves a length" beside a control
  asserting that some real token DOES — and all three had chosen
  `.Border.Rounded.Lg`, precisely because it spelled `0.5rem`. All three now
  point at `.Text.Size.Lg`. The front's README had said that no existing
  assertion covered `Sm`, `Md` or `Lg`; three did, in two other fronts, and the
  rule that came out of it is in `AGENTS.md`.

- **The stub that broke front 33 is gone, and the grid it blocked is asserted
  from both sides.** `Border.Color`'s two families at 100/500/700 are what
  collided with `Token.Color`'s own grid and made six of front 33's cells
  unreachable in EVERY spelling, the fully qualified one included, because the
  compiler resolved a leading-dot section path by hash order over a map that
  held the synthesised section enums beside the real ones. botopink-lang
  `f01c508a` fixed it — the expected type decides, the fully qualified spelling
  resolves, an ambiguous path is refused naming both candidates — so this front
  declares the FULL grid rather than keeping the narrow shades out of caution,
  and nothing was renamed to dodge a hash. Two tests pin all six cells in both
  sections and in both spellings.

- **`Outline`, `Ring` and `Divide`** — three families that had no token at all,
  and two of them are how a real component shows focus and separation. An
  outline is painted outside the border box and takes no space, which is why a
  focus ring is an outline and not a border; the example asserts that focusing
  a control adds no `border-*` and no `box-shadow`, so nothing reflows.
  **`Outline.Style.None` is the trap**: upstream prints it as
  `outline:2px solid transparent;outline-offset:2px` — a TRANSPARENT outline
  rather than an absent one, so a high-contrast mode still shows it — and never
  as `outline-style:none`. It is asserted in both directions, because only the
  absence assert catches a regression to the obvious-but-wrong transcription.

  `Ring` and `Divide` are the front's two **`…ToSheet`** dispatchers, front 56's
  second shape. A ring is a box-shadow whose `box-shadow` LISTS
  `var(--tw-shadow)` rather than writing a shadow of its own, so front 41's
  `Effect.Shadow` composes with it instead of being overwritten; swapping the
  two in one list gives a different class, which is contract 4 exercised at its
  sharpest. `Divide` declares on the element's CHILDREN, so its class body is
  EMPTY and every declaration lands under a sibling selector — and that
  selector is front 35's **`siblingSelector()`, CALLED and not re-spelled**. The
  byte-identity test front 35 could not write, because `Divide` did not exist,
  is now written twice: inside the library and from a consumer package.

- **What was verified against upstream, and what was not.** The front's spec
  specified `ring-*` and `divide-*` from memory rather than from the local
  reference, and told implementation to check. Checked and CONFIRMED: the divide
  child selector really is `& > :not(:last-child)` (not `:where()`-wrapped, not
  v3's `~ :not([hidden])` form), so front 35's spelling was right; the
  zero-then-width pair; the reverse custom properties; `--tw-ring-color`;
  `--tw-ring-inset`; and **the v4 default ring width is 1px, where v3's was
  3px**, which is the one the spec explicitly said to read rather than
  remember. Checked and NOT confirmed, recorded rather than hidden: the composed
  `box-shadow` list, and the whole `ring-offset-*` family, which v4's
  documentation no longer carries at all — it is declared because the spec asks
  for it and its acceptance depends on it, not because it was verified. The
  `--tw-ring-shadow` VALUE follows what v4 documents (`0 0 0 Npx`) and not the
  spec's v3-shaped `calc(…)` form.

- **The walk, and the probe that was not enough.** 1704 leaves are walked for a
  resolved literal, for a Tailwind class fragment and for well-formedness, each
  with a control that must fail. A literal probe alone does **not** catch this
  front's own historical defect: `border-color:teal` is not a hex, not an
  `oklch(` and not a `rem`, so a dispatcher that discarded its shade would walk
  clean. Two further walks close that — all 1440 colour cells must carry a
  `var(--color-` reference, and a section's 288 cells must be 288 DISTINCT
  declarations. Three defects were planted and watched redden before being
  removed: a radius resolving `0.125rem`, a colour arm discarding its shade, and
  a re-spelled child selector. The third reddened front 35's `Space` tests as
  well as this front's, which is the single-spelling contract working in both
  directions.

- **`examples/emilia-borders/` and `examples/emilia-outline-ring/`** — the two
  worked examples, 10 and 13 tests. Both assert full class bodies from OUTSIDE
  the library, which is what catches the cross-package `case` failure mode a
  consumer re-emitting its own enum classes used to hit.

- **`Array.lastIndexOf` does not lower on erlang** (`function lastIndexOf/2
  undefined`). Found by running the second target, not the first. Recorded in
  `AGENTS.md`; the duplicate check counts occurrences instead.

  `modules/emilia` is **419** on commonJS and on erlang, up from 375; all ten
  workspace members are green on both targets.

- **Two `AGENTS.md` rules corrected against a rebuilt compiler** (1.0.10-beta
  front `39-emilia-backgrounds`, follow-up). Front 39 measured its baseline
  against a binary built BEFORE botopink-lang's shared-name `case` fix and
  concluded that a record type name shadows an enum leaf of the same name,
  killing the arm: `.Layout.Block` answered the empty string on commonJS beside
  `output.bp`'s record `Block`. On `ef2604af` that is **fixed** — emilia's
  `feat` `e22cf80`, unmodified and with the plain `Block ->` pattern, is
  **313/313** on commonJS and on erlang. The `Block() ->` workaround the front
  had added is REVERTED, and the leaf-versus-record-name audit it came with is
  withdrawn: a workaround for a fixed defect is worse than none, because it
  teaches the next front a shape it does not need. The rule is kept only as
  FIXED, for the failure MODE — a shadowed pattern does not red, it falls out
  of the `case` and the token declares nothing, on one target only — which the
  section-head rule beside it still exhibits and front 39's 910-leaf walk still
  guards.
  What IS true and is now recorded: **`val x: Token.<Section> = .Leaf;` does
  not resolve for any leaf**, and a record sharing the name only changes the
  error text — `unbound variable 'Grid'` for an ordinary leaf against `type
  mismatch: expected __Token__Layout, got function` for `.Block`. The differing
  message reads like a shadow and is a general limitation; it is what made the
  wrong diagnosis look confirmed. A section leaf is written from the enum root.

- **`examples/emilia-backgrounds/` — the worked example** (1.0.10-beta front
  `39-emilia-backgrounds`). The new workspace member composes what the front
  unblocked: a hero panel whose photograph COVERS its box and is anchored to
  the top so a face is not cropped off, and does not scroll with the page; a
  gradient call to action; a three-stop banner whose `Via` is listed after its
  `From`, so the three-colour list is the one that survives; a gradient-text
  heading built from `bg-clip-text` plus a transparent colour — the idiom that
  needs `§ 10.2` and not just `§ 10.4`; and a texture tiling on one axis inside
  the padding box. None of the five was expressible before: `Bg` could set a
  colour and nothing else.
  Its last two tests carry the front's argument. A project's
  `--color-indigo-500` reaches `.Gradient.From.Indigo.500` and
  `.Bg.Color.Indigo.500` alike — ONE custom property, not two transcriptions
  that agree today — and the rule does not change when the project overrides
  it, only the `:root` block does. And nothing the example emits carries a `#`,
  an `oklch(`, a `rem` or a Tailwind class fragment. 12 in-file tests, green on
  commonJS and on erlang; it builds and runs.
  **The spec named two flat files, `examples/backgrounds-example.bp` and
  `examples/gradients-example.bp`.** emilia is a workspace since decision 75
  and an example is a MEMBER with its own manifest, so the two are one member —
  the same reading front 36 made of its own spec.

- **Gradient stops — `From`, `Via` and `Stop` over the whole palette, and 910
  leaves walked for a literal** (1.0.10-beta front `39-emilia-backgrounds`,
  steps 3–4). Each of the three stops carries front 33's grid — 26 families x
  11 shades plus `White`/`Black`/`Transparent`/`Current`/`Inherit`, 291 leaves
  each — and **the colour half of every one is `paletteVar(family, shade)`**,
  the same function `.Bg.Color.*` calls. `.Gradient.From.Indigo.500` and
  `.Bg.Color.Indigo.500` reference one custom property BY CONSTRUCTION rather
  than by two transcriptions agreeing, asserted as the shared substring and
  again through a project override that moves both.
  **Token order is load-bearing and deliberately so**: `Via` writes a
  three-stop list and `From` a two-stop one, whichever is listed last wins, and
  `Stop` writes no list at all so that it cannot overwrite `Via`'s. Reversing
  the two tokens reverses which list survives, pinned.
  **The stop shape diverges from this front's spec, on the strength of the
  upstream check the spec's own *Reference gaps* demanded.** The three
  custom-property NAMES check out exactly against
  `tailwindcss.com/docs/background-image` and the v4 source's
  `gradientStopUtility`. The COMPOSITION does not: upstream threads four
  position variables through the list (`--tw-gradient-position`,
  `--tw-gradient-{from,via,to}-position`) and gives `via-*` its own
  `--tw-gradient-via-stops`, both resting on `@property` registration for their
  defaults. emilia emits no `@property` block and this front declares no
  colour-stop positions, so copying that shape would emit a stop list that is
  INVALID AT COMPUTED-VALUE TIME in every browser. What is kept is the part
  that makes the simplification correct rather than merely short: upstream's
  registered `#0000` default is written as a `var(…, transparent)` FALLBACK, so
  `.Gradient.From.Indigo.500` alone still paints indigo → transparent instead
  of resolving to nothing. That is the 1.0.8 draft's shape, which this front
  carried forward `to weigh in the upstream check`; the check weighed it in.
  The front's REGRESSION walks **all 910 leaves** — the 29 keyword leaves of
  `Bg`, the eight directions and the 873 stops — through three predicates that
  take a DECLARATION STRING rather than a token, so each can be handed a value
  known to violate it: every leaf declares something non-empty carrying a `:`,
  none resolves a colour or a length (`#`, `oklch(`, `rgb(`, `rem`), and none
  emits a Tailwind class fragment. Each walk has its **control**: `.Bg.White`
  and `.Border.Rounded.Lg` fail the literal predicate, four hand-built strings
  fail the fragment one, and the well-formedness walk is run again over the
  SAME list with a predicate known to be false for part of it, so `.all` over
  this list is known to be able to answer false. Planting a `#ec4899` in one
  stop arm and a `bg-cover` in one keyword arm was confirmed to red both walks.
  The well-formedness walk is not boilerplate: a shadowed arm does not red, it
  falls out of the `case` and the token declares the EMPTY STRING, on one
  target only — the shape front 36's `Break` section was bitten by.
  20 tests; 240 → 260 in `modules/emilia`, green on commonJS and on erlang.

- **Gradient direction — `Gradient.To`, the eight phrases of `§ 10.4`**
  (1.0.10-beta front `39-emilia-backgrounds`, step 2). `Gradient` is a
  TOP-LEVEL section and not a sub-section of `Bg`: a stop sets a custom
  property and not `background-image`, so nesting the stops under `Bg.Image`
  would put three properties under one name, and a stop path
  (`.Gradient.From.Indigo.500`) is four segments already.
  **`To` is the direction and `Stop` is the terminal colour** — the one place
  this front diverges from Tailwind's own naming, where `bg-gradient-to-r` and
  `to-pink-500` share the word `to` while setting unrelated things.
  The eight phrases are spelled in exactly one place; `linearGradient(phrase)`
  builds the declaration around them and `gradientStopsVar()` is the single
  spelling of `--tw-gradient-stops`, read by the direction and by the stops.
  A corner is TWO KEYWORDS — `to top right`, never `to top-right` — and there
  is exactly one space after the comma, both pinned as absences as well as by
  `==`. 4 tests; 236 → 240, green on commonJS and on erlang.
  **Upstream check** (the front's own *Reference gaps* demanded one):
  `tailwindcss.com/docs/background-image` prints
  `background-image: linear-gradient(to top, var(--tw-gradient-stops))`, which
  is this spelling to the byte, space included. It also shows the v4 utility is
  now named `bg-linear-to-t`, `bg-gradient-to-t` being the kept v3 alias — the
  emitted CSS is the same, and the emilia path is named after neither.

- **`Bg` is no longer a colour section — `§ 10.1`, `§ 10.2`, `§ 10.5`–`§ 10.8`
  and the non-gradient half of `§ 10.4`** (1.0.10-beta front
  `39-emilia-backgrounds`, step 1). Seven keyword sub-sections sit beside front
  33's `Bg.Color`, appended after it and after the legacy leaves rather than
  interleaved: `Attachment` (3), `Clip` (4), `Origin` (3), `Pos` (9), `Repeat`
  (6), `Size` (3) and `Image.None` — 29 leaves, one declaration each, none
  resolving a length and none reading the theme.
  Three names diverge from upstream's spelling on purpose. **`Pos`, not
  `Position`**, so `.Bg.Pos.*` stays four segments and reads apart from
  `.Layout.Position.*` — Tailwind spells two unrelated properties with the same
  English word. **`Repeat.None`, not `Repeat.NoRepeat`** — the CSS value keeps
  its `no-` prefix, the token does not repeat the word its section already
  says. And **`Clip.Text` is the one clip value that is not a `*-box`**, so the
  suffix is written per arm rather than derived from the leaf: a derived rule
  emits `text-box`, which is a different value that also exists.
  The four two-word positions each carry EXACTLY ONE SPACE and no hyphen
  (`left bottom`, never `left-bottom`), asserted leaf by leaf and again as a
  space count — a doubled or missing space is the failure mode a table
  transcription produces and an `==` against a hand-typed string hides.
  The **legacy `Bg.Red` / `Bg.Blue` / `Bg.Gray` / `Bg.White` / `Bg.Black`
  leaves are byte-identical afterwards** and are pinned as such; this front did
  not fold them into `background-color`, the docs' earlier promise that it
  would notwithstanding. 11 tests; 225 → 236 in `modules/emilia`, green on
  commonJS and on erlang.

- **`examples/emilia-grid/` — the worked example** (1.0.10-beta front
  `37-emilia-grid`). The new workspace member composes the two shapes the gap
  was blocking: a toolbar that is a row from `sm` up and a stack below it, whose
  heading takes the remaining space (`flex:1 1 0%` beside `flex-basis:0`) and
  whose action neither shrinks nor leaves the end of the order; and a
  twelve-column dashboard that reflows one → six → twelve across `md` and `lg`,
  with a chart panel spanning eight of the twelve and a sidebar whose rows size
  to content. Neither was expressible before — a flex item could not grow and
  grid had no token at all. Its last two tests are the front's argument: halving
  `--spacing` gives the same class with the same declarations, and no token in
  the example resolves a length. The two compositions sit outside that walk ON
  PURPOSE and the file says why: a BREAKPOINT QUERY reads `--breakpoint-md`,
  which IS a `rem`, and that at-rule is front 34's and front 54's, not a
  declaration this front writes. 13 in-file tests, green on commonJS and on
  erlang; it builds and runs.
  **The spec named two flat files, `examples/flex-example.bp` and
  `examples/grid-example.bp`.** emilia is a workspace since decision 75 and an
  example is a MEMBER with its own manifest, so the two are one member,
  `examples/emilia-grid/`, covering both — the same resolution front 36 made.
- **The dispatchers, the walk, and the SEVENTH `rem` ladder** (1.0.10-beta front
  `37-emilia-grid`, steps 4–5). `Gap` is a TOP-LEVEL section — `gap`,
  `column-gap` and `row-gap` separate the items of a grid exactly as they
  separate the items of a flex row, so a sub-section of `Flex` was the wrong
  home for it. `All`, `X` and `Y` carry front 35's full scale and answer front
  54's `spacing(n)` / `spacingHalf(n)`.
  **`flexGapScale` is deleted.** It answered `__1 -> "0.25rem"`, `__4 ->
  "1rem"` — the last of the seven hand-written `rem` ladders front 54 found in
  `emilia.bp`, and the one front 35 could not take because `Gap` is this
  front's section under the milestone's ownership rule. `.Flex.Gap.{1,2,4,8}`
  still compiles and now emits what `.Gap.All.N` emits; the two spellings are
  compared to EACH OTHER rather than each to an expected string, so they cannot
  drift again. **`spacing.bp`'s docblock still claimed all seven for front 35**
  — front 35's README says six and lists `Gap` under *Does not touch* — and the
  docblock was the drift; it is corrected here. **No literal `rem` ladder is
  left in `emilia.bp`.**
  `flexTokenToCss`, `gridTokenToCss` and `gapTokenToCss` all take `th: Theme`,
  all are `val out = case …; return out;` with arrow arms only, and all are
  exhaustive with no `_`. Two arms joined the shared `case` in front-number
  order, after `Flex` and before `Border`.
  **THE FRONT'S REGRESSION.** A walk over all **356** leaves — 126 `Flex`, 125
  `Grid`, 105 `Gap` — asserts no declaration carries a `rem`, that every one
  carries a `:`, and that none carries a Tailwind class fragment (`gap-1`,
  `basis-`, `order-`, `flex-1`, `grid-cols-`, `col-span-`, `auto-cols-`,
  `grid-flow-`, `place-content-`, `items-start`). **The control**:
  `.Border.Rounded.Lg` is asserted to DO carry a `rem`, and a deliberate
  `0.25rem` planted in one `gapScaleAll` arm was confirmed to fail the walk
  before being taken out. A third test compares `.Gap.All.4`, `.Gap.X.12`,
  `.Flex.Basis.8` and `.Gap.All.Half.3` to the matching `Pad` leaves
  value-for-value rather than to literals. +7 in-file tests (245 → 252; the
  module is 340).
- **`Grid` — the section that did not exist** (1.0.10-beta front
  `37-emilia-grid`, step 3). `.Layout.Grid` emitted `display:grid` and there
  was nothing to put in the box: no `grid-template-columns`, no span, no start
  or end, no auto-flow, no implicit tracks. `Grid.Cols`, `Grid.Rows`,
  `Grid.Col`, `Grid.Row`, `Grid.Flow`, `Grid.AutoCols` and `Grid.AutoRows`
  close `§ 6.8`–`§ 6.14` — 125 leaves, none of them a length.
  **A template is a function of the leaf, not a lookup.** `gridRepeat(n)`
  builds `repeat(N, minmax(0, 1fr))` from the numeral, so adding a column count
  is one arm and not two, and the text is spelled in exactly one place; the
  `minmax(0, 1fr)` inside it is `gridFr()`, the SAME string `auto-cols-fr` and
  `auto-rows-fr` read, so the two cannot drift. A test compares the emitted
  values to the two functions rather than to literals.
  **`Start` and `End` run to 13** because a twelve-column grid has thirteen
  lines; `Cols`, `Rows` and `Span` run to 12. A span is the doubled
  `span N / span N` and `col-span-full` is the line-based `1 / -1` instead —
  two shapes from one sub-section.
  Two spellings that are easy to get wrong, each pinned: `grid-flow-col` is
  `grid-auto-flow:column` — the UTILITY abbreviates and the CSS value does not
  — and `grid-flow-row-dense` is `row dense`, one space and not a hyphen.
  **Reference gap, recorded rather than hidden:** `§ 6.8` prints only 1–6 and
  12, `§ 6.9` only `span-1`/`span-2`/`span-full`/`start-1`/`end-1`; the extents
  1–12 and 1–13 are declared by interpolation and must be confirmed against
  upstream before merge. +7 in-file tests (238 → 245).
- **The alignment family — seven property groups that had no token at all**
  (1.0.10-beta front `37-emilia-grid`, step 2). `§ 6.16`–`§ 6.24` is nine
  property groups and emilia carried two of them, each a third short:
  `Flex.Items` had four of the five `align-items` values and `Flex.Justify`
  five of the eight `justify-content` values. Both are complete now
  (`Baseline`; `Normal`, `Evenly`, `Stretch`), and `Flex.AlignSelf`,
  `Flex.Content`, `Flex.JustifyItems`, `Flex.JustifySelf`,
  `Flex.PlaceContent`, `Flex.PlaceItems` and `Flex.PlaceSelf` close the seven
  that were missing entirely.
  **The whole family stays under `Flex` although it applies to grid too.**
  Moving `Items` and `Justify` to a neutral section would rename two tokens
  that compile today, which the milestone forbids; a grid container writes
  `.Flex.Justify.Center` and gets `justify-content:center`, which is the
  correct CSS for a grid. Only the spelling reads as flex-only.
  **The `flex-start`-versus-`start` asymmetry is asserted, not normalised.**
  `justify-content`, `align-items`, `align-self` and `align-content` take
  `flex-start`/`flex-end`; `justify-items`, `justify-self` and `place-*` take
  `start`/`end`. One test pins all nine groups side by side and asserts
  `flex-start` does NOT survive into the four that must not carry it.
  **`Self` IS A LANGUAGE KEYWORD and the spec's `.Flex.Self` /
  `.Flex.Place.Self` do not parse** — `unexpected \`Self\`` at the declaration
  and at every arm. Unlike a section head shadowing a top-level variant, this
  fails loudly at the right line. `align-self` is `.Flex.AlignSelf` and the
  `place-*` trio is flattened with it — `.Flex.PlaceContent` /
  `.Flex.PlaceItems` / `.Flex.PlaceSelf` — the way front 36 flattened `Break`
  and the way the 1.0.8 draft spelled them. Not one emitted byte differs.
  Recorded in `AGENTS.md` § Maintainer rules. +6 in-file tests (232 → 238).
- **A flex item can finally grow, shrink, reorder and set a basis**
  (1.0.10-beta front `37-emilia-grid`, step 1). Before this, `Flex` was seven
  paths — four direction/wrap leaves, `Items`, `Justify` and a four-value
  `Gap` — so emilia could say `display:flex` and then almost nothing: no
  `flex-1`, no `grow`, no `shrink`, no `basis`, no `order`, and not one of the
  three REVERSE rows of `§ 6.2`/`§ 6.3`. `Flex.Value`, `Flex.Grow`,
  `Flex.Shrink`, `Flex.Basis` and `Flex.Order` close `§ 6.1` and
  `§ 6.4`–`§ 6.7`, and `RowReverse`/`ColReverse`/`WrapReverse` join the four
  leaves that compiled before, which emit exactly what they emitted.
  **The shorthand's sub-section is `Value`, not `Flex`** — a section cannot
  carry a sub-section of its own name — and `flex-none` is the one row whose
  value is the KEYWORD `none` and not `0 0 auto`, asserted both ways.
  `Basis` is the only length in the step and it is front 35's scale answering
  front 54's `spacing(n)`/`spacingHalf(n)`, so `.Flex.Basis.4` and `.Pad.All.4`
  are the same length by construction; its fractions are compared to
  `.Size.W.Frac.*` rather than to literals, because `basis-1/3` and `w-1/3` are
  one fraction and must not drift into two. `Grow`, `Shrink` and `Order` are
  BARE NUMBERS and reach `spacing` never — `order-first` is the sentinel
  `-9999`, `order-last` `9999`, and `order-none` is `0`, with `order:none`
  asserted absent. +7 in-file tests (225 → 232 in `emilia.bp`), green on
  commonJS and on erlang.

- **`examples/emilia-layout/` — the worked example** (1.0.10-beta front
  `36-emilia-layout`). The new workspace member composes what the front
  unblocked: a media card that CLIPS its overflow, isolates a stacking context
  and crops a 16:9 image to fill rather than squash it; and a sticky header
  that stacks over a panel scrolling on one axis, with a badge hanging off a
  relative card on a NEGATIVE inset. None of the five was expressible before —
  there was no `overflow`, no `isolation`, no `aspect-ratio`, no `object-fit`,
  no `position` and no inset of any kind.
  Its two closing tests are the front's argument: `.Layout.Inset.T.4` and
  `.Pad.T.4` are compared to EACH OTHER rather than each to its own expected
  string, and halving `--spacing` gives the same class with the same
  declarations — only the `:root` block moves. 12 in-file tests, green on
  commonJS and on erlang; it builds and runs.
  **The spec named two flat files, `examples/layout-example.bp` and
  `examples/position-example.bp`.** emilia is a workspace since decision 75 and
  an example is a MEMBER with its own manifest, so the two are one member,
  `examples/emilia-layout/`, covering both.
- **The dispatcher contract, and 776 leaves walked for a resolved length**
  (1.0.10-beta front `36-emilia-layout`, step 6). `layoutTokenToCss(t, th)` and
  every sub-dispatcher under the front 36 banner now carry `th: Theme`, each is
  `val out = case …; return out;` with arrow arms only, and each is exhaustive
  with no `_` — so a leaf added to `Layout` reds its own dispatcher rather than
  falling through. The shared `case`'s `Layout` arm is the one line this front
  changed there; no new top-level arm was added.
  The front's REGRESSION walks **all 776 `Layout` leaves** and asserts no
  declaration carries a `rem`, that every one carries a `:`, and that none
  carries a Tailwind class fragment (`inset-x-`, `top-`, `z-50`,
  `overflow-auto`, `float-start`, `box-border`). The same test asserts
  `.Border.Rounded.Lg` DOES carry a `rem`, so the probe is known to
  discriminate; a deliberate `0.25rem` planted in one inset arm was confirmed
  to fail it.
- **Multi-column, fragmentation and box-sizing — and the column widths are the
  theme's** (1.0.10-beta front `36-emilia-layout`, step 5). `Layout.Columns`,
  `Layout.Break { After, Before, Inside }`, `Layout.Box` and
  `Layout.BoxDecoration` close `§ 5.2`–`§ 5.6`.
  **The front's spec printed the fourteen named column widths as `rem`
  literals — `columns-md` → `columns:28rem` — and that is a defect, not a
  transcription.** Front 54's theme already carries `--container-md: 28rem` and
  front 35's `.Size.MaxW.Md` already reads it, so `columns:28rem` would be a
  SECOND spelling of one width: a project overriding `--container-md` would see
  its `max-width` move and its `columns` stay put. `.Layout.Columns.Md` emits
  `columns:var(--container-md)` through front 35's `containerVar`, and a test
  asserts the thirteen named widths carry no `rem` and that the `columns` value
  and the `max-width` value are the same string.
  The three counts are not lengths — `columns-2` is `columns:2` — and
  `break-inside` keeps its own shorter leaf set, `§ 5.5` having no `all`, no
  `page`, no `left` and no `right`.
  **`Break` is FLAT — `BreakAfter` / `BreakBefore` / `BreakInside` — and the
  spec's `Break { After, Before, Inside }` does not survive beside front 34.**
  A section head named like a TOP-LEVEL payload variant does not red; it
  silently breaks THAT variant's payload projection, so `Token.Before(inner)`
  built a record with no `inner` field and three of front 34's tests died on
  `undefined.fold` — in another front's block, with nothing pointing back at
  the section that caused it. `After` and `Before` were the only two
  collisions; leaf names such as `Columns.Md` beside the `Md` modifier are
  harmless, and always were. The flat spelling is the 1.0.8 draft's, it cannot
  collide, and not one byte of emitted CSS changed. Recorded in `AGENTS.md`
  § Maintainer rules and reported to botopink-lang: a name that cannot be
  constructed should not capture a constructor that can.
  **Reference gap, recorded rather than hidden:** `columns-4` … `columns-12`
  resolve upstream through the bare-integer rule rather than through a theme
  key, so they are left undeclared until that is confirmed.
- **Float, clear, and an image that can be cropped** (1.0.10-beta front
  `36-emilia-layout`, step 4). `Layout.Float` and `Layout.Clear` answer
  `§ 5.9`/`§ 5.10`, `Layout.Object` the `Fit`/`Pos` split of `§ 5.12`/`§ 5.13`,
  and `Layout.Aspect` the three ratios of `§ 5.1`.
  Three name-versus-value traps, each with its own assertion rather than a
  shared one: **`float-start` is `float:inline-start`** (and `clear-start` is
  `clear:inline-start`) — the utility carries the logical name, CSS carries the
  logical VALUE, and `float:start` is not a value at all; the four two-word
  object positions are **one space, not a hyphen** — `object-left-bottom` is
  `object-position:left bottom`, and a test asserts `left-bottom` does not
  survive into the declaration; and `aspect-square` is **`1 / 1` with spaces
  around the slash**, the way `§ 5.1` prints it, with `16/9` asserted absent.
- **A scroll container, a stacking order and a box that keeps its space**
  (1.0.10-beta front `36-emilia-layout`, step 3). `§ 5.14`, `§ 5.15`, `§ 5.18`,
  `§ 5.19` and `§ 5.11` had no token: emilia could not clip, could not scroll,
  could not stack and could not hide an element while keeping its space.
  `Layout.Overflow` answers five values on the shorthand and five on each of
  `X`/`Y` — three properties, not one property with an axis flag — and
  `Layout.Overscroll` three on each of the same three. `Layout.Visibility`,
  `Layout.Z` and `Layout.Isolation` complete the step.
  **`invisible` is the UTILITY name and `hidden` is the CSS value**, and a
  transcription that carried the name through would emit
  `visibility:invisible`, which no browser honours; the test asserts the value
  AND that the word `invisible` does not survive into the declaration.
  `Z` is the one numeric family in this front that is not a length: `z-50` is
  `z-index:50`, a bare integer that never reaches `spacing` and that a test
  pins as carrying no `calc`, no `rem` and no `px`.
- **`position` and the whole inset family** (1.0.10-beta front
  `36-emilia-layout`, step 2). Nothing in emilia could be positioned, and no
  positioned box could be placed: `§ 5.16` and `§ 5.17` had no token at all.
  `Layout.Position` answers the five values and `Layout.Inset` the **nine
  directions front 35's `Pad` and `Margin` already carry** — `All`, `X`, `Y`,
  `T`, `R`, `B`, `L` and the logical pair `S`/`E` — over the **same scale**,
  answering the **same** `spacing(n)` / `spacingHalf(n)`, plus `Auto`, `Full`,
  `Frac { Half, Third, TwoThirds }` and a `Neg` sub-section per direction for
  `-top-4`. `.Layout.Inset.T.4` and `.Pad.T.4` therefore carry identical length
  text BY CONSTRUCTION rather than by two transcriptions that agree today; a
  test asserts the two values are equal rather than asserting each separately.
  `inset` is a real CSS shorthand so `All` is one declaration, while `X` and `Y`
  expand to `left:…;right:…` and `top:…;bottom:…` — `§ 5.17`'s own printing —
  through front 35's `axisDecl`, reused rather than re-spelled.
  `layoutTokenToCss` takes `th: Theme` from this step on, which is this front's
  one line of the shared `case` and nothing else of it.

- **The eleven display values, and the front 36 banner in both files**
  (1.0.10-beta front `36-emilia-layout`, step 1). `Layout` carried six of
  `§ 5.8`'s eleven display values; `InlineFlex`, `InlineGrid`, `Contents`,
  `FlowRoot` and `ListItem` are added as BARE SIBLINGS of the six, inside
  `Layout` itself and not under a sub-section, which is what keeps
  `.Layout.Flex` spelled the way every consumer spells it today. The six that
  predate this front emit byte-identical CSS, pinned by an assertion that lists
  them first. `// ── front 36 — layout ──` now fences the section in `tokens.bp`
  and `layoutTokenToCss` with its sub-dispatchers in `emilia.bp`; the front's
  tests live beside the dispatchers, not at the end of the file, for the reason
  front 35 records — two fronts appending to the same last line cannot be
  merged.

- **`examples/emilia-modifiers/`, the front's worked example** (1.0.10-beta
  front `34-emilia-modifiers`, § Examples). A new workspace member, and the
  first thing in this repository that uses the table across a PACKAGE
  BOUNDARY — which is where the commonJS `case`-over-a-unique-variant defect
  used to bite, so it is worth a runnable example rather than an inline test.
  A navigation bar stacked and dark-surfaced on a phone and a row from `md:`
  up, whose links read the bar's hover through `.group` and their own through
  `:hover`; a form field whose error message is shown by its SIBLING's invalid
  state and by nothing else; a self-striping table that also carries
  `Important`; and one panel rendered under all three `DarkMode` strategies,
  which give three different classes because the strategy reaches the rule. Two
  assertions pin other fronts' output and say so in place — `Margin.*.__0` is
  `margin-left:0`, and `Border.Color.Red.__500` is still `border-color:red`
  because that section is pre-front-33 and front 40 owns the rewrite; what the
  example pins there is the SELECTOR. 16 in-file tests, green on commonJS and
  on erlang; it builds and runs.

- **`Important`, the walks, and the table closed at 83**
  (1.0.10-beta front `34-emilia-modifiers`, step 7). `Important(inner)` is
  decision 81's row and the one that is not a variant at all: it adds no
  selector and no at-rule, it is one line on top of front 56's `markImportant`,
  and it flags every rule it wraps. The front's own regression is six walks
  over the WHOLE table rather than row by row — every selector template carries
  exactly one `&`; no selector and no at-rule carries a brace, because **this
  front builds none**; every at-rule starts with `@`; no two rows resolve to
  the same `(atRule, selector)` pair; every modifier wraps its declaration and
  none drops it; no query resolves a pixel or says `min-width`/`max-width`; and
  no variant carries a codec separator. An empty inner list produces an empty
  `Sheet`, which `declSheet`'s contract already drops, and that is tested on
  four shapes rather than asserted in prose. Three end-to-end documents close
  it: a dark override, a responsive stateful button whose four rules come out
  in cascade order, and a peer-driven error message.
  **283/283** on commonJS and on erlang (145 → 195 in `emilia.bp`), every
  example builds.

- **Parent, sibling, direction and descent** (1.0.10-beta front
  `34-emilia-modifiers`, step 6). Six `Group*` and eight `Peer*`, each built by
  substituting a state into the reference's two templates, written once:
  `groupVariant(state)` is `&:is(:where(.group)<state> *)` and
  `peerVariant(state)` is `&:is(:where(.peer)<state> ~ *)`. **`.group` and
  `.peer` are the consumer's classes** — emilia emits the selector that reads
  them and never the class itself, which is now stated in `docs.md` beside the
  table. `GroupVisited`, `PeerActive` and `PeerRequired` come from the front's
  *Carried from 1.0.8-beta* section, translated into the v4.3 template as that
  section spells out. `Rtl` and `Ltr` are the rows where the class is NOT
  leading — `[dir="rtl"] &` — and `Children`/`Descendants` are the rows where
  it is wrapped — `:is(& > *)` and `:is(& *)`; all four go through the same
  `selector` field as `&:focus`, which is the whole argument for the one-`&`
  template. 269/269 on both targets.

- **The nine pseudo-elements** (1.0.10-beta front `34-emilia-modifiers`,
  step 5). `Before`, `After`, `FirstLetter`, `FirstLine`, `Placeholder`,
  `File` (`&::file-selector-button`) and `Backdrop` take `&::`; `Marker` and
  `Selection` take `& ::` — **the space is the reference's and is copied, not
  corrected**, and a test asserts the two spellings against each other so a
  tidy-up shows up as a change. The nesting direction matters here and is
  pinned: `Hover([Before([…])])` flattens to `&:hover::before`, never to
  `&::before:hover`, because front 56 substitutes the INNER rule's `&` with the
  OUTER variant's selector. `Before`/`After` stay useless until front 38
  delivers `Text.Content.*`. 261/261 on both targets.

- **Thirty-six state variants, and the two that take an index**
  (1.0.10-beta front `34-emilia-modifiers`, step 4). Six more interaction
  states (`FocusWithin`, `FocusVisible`, `Visited`, `Target`, `Open`,
  `Inert`), the sixteen form states a form cannot be styled without
  (`Disabled` … `ReadOnly`), nine structural positions, and `Nth(index, inner)`
  / `NthLast(index, inner)`, which build their selector from an `i32` payload
  carried beside the list.
  **One reference row did not survive front 56.** `§ 3.2` spells `open` as
  `&:open, &:popover-open` — two `&`, which `checkVariantSelector` refuses with
  no opt-out, correctly: a two-`&` template DUPLICATES the rule it wraps. The
  two states go inside one `:is()` instead — `&:is(:open, :popover-open)` —
  which is one `&`, the same match set, and no selector list for front 56 to
  split. Worth a reader's attention: upstream v4.1 additionally carries the
  legacy `[open]` attribute in that row, which the local reference's table does
  not, so the row is transcribed from the reference and not from upstream.
  257/257 on both targets.

- **`Dark`, and the other eight media features** (1.0.10-beta front
  `34-emilia-modifiers`, step 3). `darkVariant(th)` is
  `Variant(atRule: darkAtRule(th), selector: darkSelector(th))` — it consumes
  front 54's pair and **never learns which `DarkMode` strategy is in force**,
  which is what makes all three work from one row: `Media` puts the whole
  strategy in the at-rule over a bare `&`, `Class` and `Attribute` put it in a
  `:where()` selector with no at-rule at all. A cell proves each, and a fourth
  pins that the strategy reaches the class hash. **This is where the README is
  out of date**: its step 3 calls the class- and attribute-based forms
  `@custom-variant` registrations and rules them out of scope, which was true
  before front 54 shipped `DarkMode` and decision 82 assigned the consumption
  to this front. `Print`, `Portrait`, `Landscape`, `MotionSafe`,
  `MotionReduce`, `ContrastMore`, `ContrastLess` and `ForcedColors` are
  at-rule-only rows beside it. 247/247 on both targets.

- **Ten breakpoints, both directions, every one of them read from the theme**
  (1.0.10-beta front `34-emilia-modifiers`, step 2). `Sm` and `X2xl` close the
  two ends the enum could not address at all, and `MaxSm`/`MaxMd`/`MaxLg`/
  `MaxXl`/`MaxX2xl` are the `max-*` mirrors. `breakpointVariant` emits
  `@media (width >= <n>)` and `maxBreakpointVariant` `@media (width < <n>)`,
  both resolving the SAME `--breakpoint-*` entry (decision 82), so a project
  that moves `md` moves `md:` and `max-md:` together — and moves the class
  hash with them, which a test pins. No breakpoint resolves a pixel: the
  `rem` values are the theme's. A RANGE is nesting and not a name — upstream's
  `md:max-xl:` is `Token.Md([Token.MaxXl([…])])`. 240/240 on both targets.

- **The six modifiers move under front 34's banner, unchanged**
  (1.0.10-beta front `34-emilia-modifiers`, step 1). Front 56 had already
  corrected what they emit — `hover` is `@media (hover: hover){&:hover}` and a
  breakpoint is `@media (width >= 48rem)` read from `--breakpoint-md`, not
  `:hover` and `@media(min-width:768px)` — and had said so in a comment naming
  front 34 as the owner. **Step 1 of the front's README is therefore already
  landed**: the six `Variant`-returning fns and the four helper shapes move
  into the `// ── front 34 — modifiers ──` block, the arms of `tokenToSheet`
  are fenced by the same banner, and not one byte of CSS changes. The README's
  step 1 also names five assertions in `src/emilia.bp` that the correction
  breaks; front 56 updated them when it made the correction, and there is
  nothing left to update. 233/233 on commonJS and on erlang, unchanged.

- **`examples/emilia-card` stops pinning a compiler defect.** The commonJS
  `case`-over-a-uniquely-named-variant defect recorded further down this file
  is **fixed upstream**: such an arm now compares the `tag` string instead of
  testing `instanceof`, so a value built in a consumer package is matched by
  the library again. `.Text.Size.X3xl` and `.Text.Size.Base` reach the CSS, and
  the example's two class-body assertions — written to pin the pre-fix shape so
  the fix would show up as a change there — are rewritten to the real output:
  `.e_…{font-size:1.875rem;font-weight:bold;color:var(--color-red-600)}` and
  `.e_…{font-size:1rem;color:var(--color-gray-600)}`. The comment declaring
  them pinned is gone. Nothing in the library changed; `botopink test` in
  `examples/emilia-card` is 4/4 on its one declared target, commonJS. The
  example's 600 shades stay 600: front 33 moved them off 500 to dodge the
  leading-dot section resolver. **That defect is closed since `1cd39b2`** —
  `.Color.Red.500` and `.Color.Gray.500` resolve, and the note above
  `colorTokenToCss` records it rather than blocking on it.

- **`examples/emilia-spacing/`, and the front 35 block is fenced in both files**
  (1.0.10-beta front `35-emilia-spacing-sizing`, step 5). The
  `// ── front 35 — spacing and sizing ──` banner now fences the four sections
  in `tokens.bp` as well as the four dispatchers in `emilia.bp`. A line comment
  inside the `Token` enum body was recorded as a parser gotcha and is not one
  any more: measured green on both targets and on every example, and the note
  in `AGENTS.md` is corrected rather than worked around.
  The new workspace member `examples/emilia-spacing/` is the front's worked
  example — the multiplier scale, the nine directions, `auto`, negatives,
  a centred article shell as one class and one rule, a full-bleed header whose
  `-mx-6` cancels it, fractions, the per-axis viewport unit, `size-12`, the six
  logical forms, and a comment thread spaced by `Space.Y` with a reply pulled up
  by `-mt-2`. Its last two tests are the front's whole argument: no token in it
  emits a resolved length or a class fragment, and **halving `--spacing` gives
  the same class with the same declarations — only the `:root` block moves**.
  12 in-file tests, green on commonJS and erlang.
  `examples/emilia-cascade/` had four assertions pinning `padding:1rem` and
  `padding:2rem`; they now pin `calc(var(--spacing) * 4)` and
  `calc(var(--spacing) * 8)`, which is the correction this front owns.

- **`Space` — the first emilia token that declares on something other than the
  element** (1.0.10-beta front `35-emilia-spacing-sizing`, step 4).
  `space-x-*` / `space-y-*` set a margin on an element's CHILDREN, so
  `spaceTokenToSheet(t, th) -> Sheet` is the second of the two shapes contract
  4a defines and the one arm of `tokenToSheet` that does not go through
  `declSheet`. Its rule carries the nesting template
  **`& > :not(:last-child)`**, so `emilia([.Pad.All.4, .Space.Y.4])` renders as
  two rules of one class — `.e_x{padding:…}` and
  `.e_x > :not(:last-child){margin-block-end:…}` — and a modifier wraps the
  child selector rather than replacing it (`&:hover > :not(:last-child)`).
  The selector is `pub fn siblingSelector()`, written once: **front 40's
  `divide-*` must call it** rather than re-spell it. `X` is
  `margin-inline-end` and `Y` is `margin-block-end`, the logical pair, over the
  same scale and the same `Neg` as `Margin`; `XReverse`/`YReverse` set
  `--tw-space-x-reverse` / `--tw-space-y-reverse`.
  **Reference gap, recorded rather than hidden:** `space-*` is absent from the
  local `TAILWIND_CSS_DOCS.md` entirely, so both the child selector and the
  property are this front's proposal and not a transcription, and the two
  `--tw-space-*-reverse` names are upstream-internal and unverified. A test
  pins each, so changing one is a visible change.

- **`Size` — a component can be given a width** (1.0.10-beta front
  `35-emilia-spacing-sizing`, step 3). There was no sizing section at all: no
  width, height, min or max token of any kind. `Token.Size` carries thirteen
  sub-sections over `§ 8.1`–`§ 8.7` — `W`, `H`, `Both` (upstream's `size-*`, two
  declarations from one leaf), `MinW`, `MaxW`, `MinH`, `MaxH` and the six
  logical `Inline`/`Block` forms — 566 leaves of four kinds. A NUMBER is the
  spacing ladder again (`w-64` is `width:calc(var(--spacing) * 64)`); a `Frac`
  is a percentage carried by name, because `1/2` is neither an identifier nor a
  run of digits; a KEYWORD is an intrinsic size or a viewport unit, and **the
  viewport unit differs by axis** — `w-screen` is `100vw` where `h-screen` is
  `100vh`, asserted directly.
  **The named container widths are the theme's**: `.Size.MaxW.Md` is
  `max-width:var(--container-md)`, not `max-width:28rem`, built through a
  `containerVar` over front 54's `nsPrefix(Ns.Container)` and `themeVar` — the
  same shape as front 33's `paletteVar`. `MaxW.Screen.*` reads `--breakpoint-*`
  the same way. Front 54's theme already carried all thirteen container sizes
  and five breakpoints with exactly the lengths `§ 8.3` prints, so the front
  spells no `rem` of its own: a walk over all 566 leaves asserts the output
  carries none, and a second test reads every name back through `themeValue` so
  the reference AND the length are both pinned. `MaxW` carries all thirteen
  container names — `X3xs` and `X2xs` as well as the `Xs`..`X7xl` the spec
  lists — because the theme carries them and upstream has the utilities.

- **Nine directions for padding and margin, over a 35-leaf scale** (1.0.10-beta
  front `35-emilia-spacing-sizing`, step 2). `Pad` and `Margin` had three
  directions (`X`, `Y`, `All`) over five values and no `p-0` at all; they now
  carry `All`, `X`, `Y`, `T`, `R`, `B`, `L` and the logical pair `S`/`E`
  (`padding-inline-start` / `padding-inline-end`) over the thirty multipliers of
  upstream's default theme plus `Px` and `Half { 0, 1, 2, 3 }` — `0.5` cannot be
  an enum leaf, a numeric leaf being a run of digits, so `Half.1` reads "one and
  a half". `Auto` moved from `Margin.X` alone to every margin direction, and
  each of the nine gained a **`Neg` sub-section** — `-mt-4` is
  `.Margin.T.Neg.4`, a five-segment path, answering `spacing(-4)`, and it is the
  one Tailwind family with no alternative spelling. 936 leaves, every one of
  them a multiplier of `--spacing` and none of them a length: a test walks all
  936 through the public dispatcher and asserts the output carries no `rem`, no
  non-property and no class fragment.
  **`Neg.Half` is `{ 1, 2, 3 }`, not `{ 0, 1, 2, 3 }`** — `spacingHalf(-0)` is
  `spacingHalf(0)`, an `i32` having no negative zero, so `-0.5` is the one rung
  of front 54's ladder that cannot be spelled and this front declines to write a
  second `calc(var(--spacing) * …)` to reach it. Front 54 owes a signed half
  step; until then `-mt-0.5` has no token rather than a wrong one.

- **Spacing stopped emitting text that is not CSS** (1.0.10-beta front
  `35-emilia-spacing-sizing`, step 1). Three of emilia's ten sections emitted
  strings no browser can read, and all three were here. `padTokenToCss`
  answered `padding-x:` and `padding-y:` — **there is no `padding-x` property**,
  so `px-4` and `py-4` were silently discarded by every browser; `Pad.X` now
  answers the two real properties, `;`-joined inside the one token
  (`padding-left:… ;padding-right:…`), and `Margin.Y` likewise instead of
  `margin-y:`. `marginScaleX` was worse: it answered `m-0.25`, `m-0.5`, `m-1`,
  `m-2` and `margin-auto` — **Tailwind class fragments**, in a position where
  only a declaration is legal. `Margin.X.Auto` is `margin-left:auto;margin-right:auto`
  now, `Auto` having become a value on the ladder rather than a property.
  The six hand-written `rem` ladders (`padScaleX/Y/All`,
  `marginScaleX/Y/All`) are **deleted, not widened**: every leaf answers front
  54's `spacing(n)`, so a value is `calc(var(--spacing) * N)` and a project's
  `--spacing: 4px` override finally reaches the utilities that consume it.
  This changes the CSS four existing tokens emit and the front owns the break —
  no path that compiled stops compiling, and what those paths emitted was never
  valid CSS. Eight tests pin it, including one walk over every `Pad`/`Margin`
  leaf asserting that `padding-x`, `padding-y`, `margin-x`, `margin-y`,
  `m-0.25`, `m-0.5`, `m-1`, `m-2`, `margin-auto` and the substring `rem` appear
  nowhere in the output.

- **The colour palette resolves through the theme** (1.0.10-beta front
  `33-emilia-color-palette`, step 1). `Token.Color` is the 26-family x
  11-shade grid of `§ 3.6` / `§ 21.1` — the seventeen chromatic families
  `Red..Rose` and the nine neutral `Slate..Taupe`, each `50 100 … 900 950` —
  plus `White`, `Black`, `Transparent`, `Current`, `Inherit` and the retained
  `Hex(string)` escape. **The emitted CSS changed and this front owns the
  break**: `colorTokenToCss` answered `"color:red"` for every shade of Red, so
  `.Color.Red.100` and `.Color.Red.900` rendered byte-identically and the shade
  level existed in the type and did nothing. It now answers
  `color:var(--color-red-500)`, byte-equal with upstream's own `.text-red-500`
  rule, built by the new `pub fn paletteVar(family, shade)` over front 54's
  `themeVar` and front 54's `nsPrefix(Ns.Color)` — **no literal ladder, and the
  `--color-` prefix still has exactly one author in the library**.
  `redPaletteHex`, a correct nine-shade ladder of v3 hex values that nothing
  called, is deleted. `.Color.White` / `.Color.Black` follow the theme too
  (`var(--color-white)` / `var(--color-black)`), which rewrites five front-56
  assertions and the two examples that pinned the hex.

- **The palette is a string-to-string mapping, with the enum at its edge**
  (front `33-emilia-color-palette`, step 5). `paletteVar(family, shade)` and
  `alphaWrap(percent, css)` are `pub` and take plain strings; the property name
  (`color:`, `background-color:`) lives in the dispatcher rather than in the
  value; no function in the front takes a `Token.Color` where a `string` would
  do. So front 57's escape hatch can hand a colour this enum does not carry to
  the same formatter and get a well-formed declaration back, without a second
  palette table and without this front changing shape. `Color.Hex(value)` is
  retained unchanged as the proof that a string payload splices — and recorded
  as **unconstructible**, with the exact compiler errors measured against
  `zig-out/bin/botopink`: `Token.Color.Hex("#abc")` reds `'Hex' is not declared
  in any behavior implemented for 'Token'`, and `val h: Token =
  .Color.Hex("#abc");` reds `unbound variable 'Color'`. A payload-carrying
  token has to be a top-level variant with builtin-typed fields.

- **`Alpha(percent, inner)` — upstream's `/N` opacity suffix** (front
  `33-emilia-color-palette`, step 4). `bg-red-500/50` is the most used colour
  form in real markup and v0 had no token for it. `Token.Alpha(percent: 50,
  inner: [.Bg.Color.Red.500])` emits `background-color:color-mix(in oklab,
  var(--color-red-500) 50%, transparent)`. A **top-level** variant with a
  builtin-typed field, because opacity cannot be a leaf under the family (the
  shade already is one) and a payload leaf nested in a section has no
  constructible spelling. **It rewrites a `Sheet`, not a string** — the spec's
  `alphaWrap(percent, tokensToCss(inner))` predates front 56, and folding the
  inner tokens back to one string would flatten away the selector and at-rule
  of any modifier inside, so `Hover([Alpha(…)])` and `Alpha([Hover(…)])` both
  work and both are pinned. A non-colour token is rewritten too and the result
  is meaningless CSS, deliberately: a silently dropped declaration hides the
  mistake, one a browser discards does not. `alphaWrap(percent, css)` is `pub`
  and takes plain strings, for front 57. No `String.slice` anywhere — `split` +
  `at` + the ARRAY `slice` do the same job without installing the prelude whose
  `charCodeAt` patch is self-recursive.

- **`paletteEntries()` — the 286 numeric values, as data** (front
  `33-emilia-color-palette`, step 3). The other half of the mechanism: the
  utility emits `var(--color-red-500)` and this declares it. A plain
  `ThemeEntry[]`, not a rendered block, so a consumer composes it —
  `extendTheme(defaultTheme(), paletteEntries())` — and front 54's `themeCss`
  renders it into the `theme` layer. Keeping it a list is what lets a project
  that already imports upstream's own theme leave it out and still use every
  colour token; `emilia(...)` emits no `@theme` block of its own at any size of
  token list. Transcribed from upstream `tailwindcss` **4.3.2**'s `theme.css`;
  `--color-white` / `--color-black` stay front 54's and are not duplicated.
  **The two anchor values are in upstream's spelling, not the reference's**:
  `§ 3.6` prints `oklch(0.637 0.237 25.331)` for red-500 and upstream writes
  `oklch(63.7% 0.237 25.331)` — the same lightness, two spellings — and
  byte-parity with the emitted block is what is worth having.

- **`Bg.Color` — the palette on `background-color`** (front
  `33-emilia-color-palette`, step 2). The same 26 x 11 grid and the same five
  named colours under a sub-section of `Bg`, and **all 286 cells resolve**:
  `Bg` is a head segment no other enum carries, so the four-segment path
  `.Bg.Color.Red.500` has no hash-order tie to lose and is the way to reach the
  six shades `.Color.Red` / `.Color.Gray` cannot. The property is
  `background-color`, the longhand upstream sets (`§ 10.3`) — the `background`
  shorthand the v0 stub emitted resets every other background property of the
  element as a side effect. `bgTokenToCss` is front 39's and gains exactly two
  things from this front: the `Color` arm and the `th: Theme` parameter contract
  4a asks of every sub-dispatcher. Its four legacy leaves (`.Bg.White`,
  `.Bg.Black`, `.Bg.Red.500`, `.Bg.Gray.500`) keep the shorthand and the output
  they had, so nothing that compiled changed meaning.

- **Six colour cells are declared and unreachable** (front
  `33-emilia-color-palette`). `.Color.Red.{100,500,700}` and
  `.Color.Gray.{100,500,700}` do not compile in any spelling. The compiler's
  leading-dot section resolver scans every registered enum — the synthesised
  section enums included — and returns the first whose tree carries the path,
  never consulting the expected type; `Token.Border.Color` (front 40's stub)
  carries the same six leaves, so hash order decides and today it decides
  against `Token`. It reds at the call site rather than emitting the wrong CSS.
  `examples/emilia-card/` moved from `.Color.Red.__500` / `.Color.Gray.__500`
  to the 600 shade for that reason, with the cause written above the tokens.
  Reported to botopink-lang; `.Bg.Color.<Family>.<shade>` reaches every shade
  unaffected, because `Bg` is a head segment no other enum carries.

- **`examples/emilia-cascade/`** (1.0.10-beta front
  `56-emilia-cascade-and-output`, Examples). A new workspace member, the
  front's worked example: one card whose styles reach outside its own class.
  The hover is a **sibling rule** (`@media (hover: hover){.e_x:hover{…}}`) and
  not a block nested in the class body; the breakpoint is a hoisted
  `@media (width >= 48rem)` whose width is read from the theme's
  `--breakpoint-md`, so overriding the variable moves the breakpoint; the reset
  arrives through `Options` and lands in its own `base` layer behind a
  **literal** selector the class name and the prefix never reach; and the
  document is layered, which is what lets a project's own CSS beat a utility
  deliberately rather than by accident of order. Ten in-file tests, green on
  commonJS and on erlang, also covering `withPrefix`, `withLayers(o, false)`,
  `withImportant(o, true)` and the two-flush contract.

- **The host cell is a dumb string store** (1.0.10-beta front
  `56-emilia-cascade-and-output`, step 5). `flushSheet()` is **gone** and
  `drainRules()` takes its place: it hands back the registered entries as
  `name + "\t" + payload` records joined by `"\n"`, in insertion order, and
  clears the cell — the same per-render contract. `flushSheet` assembled the
  `<style>` document **inside** the two `#[compiler.external]` templates, once in
  JavaScript and once in Erlang, which is where the byte-level divergence risk
  lived and where nothing written in botopink could reach it. Keeping it as
  the spec's step 5 asks would have left exactly the duplicate assembly the
  front's own definition of done forbids, and nothing outside `emilia.bp`
  could name it. Five tests now pin the two templates against each other on
  both targets.

- **`emiliaWith` / `flushWith`, and a document with layers in it** (front
  `56-emilia-cascade-and-output`, step 7). `emiliaWith(tokens, th)` and
  `flushWith(o)` are the new entry points; `emilia(tokens)` is
  `emiliaWith(tokens, defaultTheme())` and `flush()` is
  `flushWith(defaultOptions())`, both with the signatures they had, so no
  consumer changes. What changed is **the emitted CSS**, and this front owns
  the break: `[.Bg.Black, Hover([.Bg.White])]` went from
  `<style>.e_x{background:#000000;:hover{background:#ffffff}}</style>` to a
  layered document whose modifier is a **sibling rule**, hoisted out with the
  selector and at-rule the variant reference gives it. The six modifier tests
  in `emilia.bp` and the flush test in `examples/emilia-card/` are rewritten to
  the hoisted shape and each names the row it comes from.

- **The six V1 modifiers, against the variant reference** (front
  `56-emilia-cascade-and-output`, step 7). `hoverVariant()` is
  `@media (hover: hover) { &:hover }` and not a bare `:hover`;
  `focusVariant()`/`activeVariant()` are selector-only; `mdVariant(th)`,
  `lgVariant(th)` and `xlVariant(th)` are `@media (width >= 48rem | 64rem |
  80rem)` and not `@media(min-width:768px)`. A breakpoint **reads its width
  from the theme**, so a project that overrides `--breakpoint-md` gets its own
  media query — and so the theme is genuinely an input to the class hash,
  which is contract 4's clause 1 amended. Front 34 moves the six into its own
  variant table and adds the rest.

- **The conflict rule, written down and tested** (front
  `56-emilia-cascade-and-output`, step 8). The last rule in the stylesheet
  wins: inside one `emilia()` call that is the token list order, across calls
  it is registration order, and before this front nothing said either —
  `flushSheet` iterated a `Map` on commonJS and a `lists:keystore` list on
  erlang and no test compared them. `[.Layout.Grid, .Layout.Flex]` renders
  `display:grid;display:flex`, reversing the list reverses the winner and is a
  different class, two calls render in call order, and reordering an unrelated
  token moves no other rule.

- **The drain stream layers two separators on one character, and that is
  resolved rather than avoided** (front `56-emilia-cascade-and-output`, step
  5). The cell joins its entries with `"\n"` and each payload joins its own
  records with `"\n"`; the front's spec writes both without noticing. It stays
  unambiguous because a payload record is **tagged**: a line whose first field
  is `R` or `B` continues the entry above it, and any other line opens a new
  one. A registered name is `e_<hex>`, so it is never `R` or `B`.

- **`String.prototype.charCodeAt`'s commonJS prelude patch is self-recursive**
  (found by front `56-emilia-cascade-and-output`). The backend installs the
  whole `String` behavior prelude into any module using a member that needs a
  patch — `slice` is one — and that prelude writes
  `String.prototype.charCodeAt = function(index) { return ((this.valueOf().charCodeAt(index) ?? -1) | 0); }`,
  which calls the patch it has just installed. One `s.slice(…)` anywhere in
  `output.bp` therefore made `hashHex`'s host template blow the stack for every
  non-empty class body, on commonJS only. `output.bp` splits on the separator
  instead of slicing. Reported to botopink-lang.

- **A `case` arm over a uniquely-named variant lowers to `instanceof`, and
  `instanceof` does not cross a package boundary** (found by front
  `56-emilia-cascade-and-output`, pre-existing). The commonJS backend lowers an
  arm whose variant name is unique in the program to
  `if (_s instanceof __Token__Text__Size$X3xl)` and an arm whose name repeats
  to `if (_s.tag === "Lg")`. A consumer package re-emits its own copy of the
  enum classes, so a value built in `examples/emilia-card/` is never
  `instanceof` the class `emilia` matches against: the whole `case` falls
  through and answers `undefined`. `.Text.Size.X3xl` and `.Text.Size.Base`
  have gone missing from that example's two class bodies since before this
  front — the pre-56 document read `.e_x{;font-weight:bold;color:red}`, and the
  empty leading declaration is the same token going nowhere — while
  `.Text.Size.Lg` survives only because `Lg` repeats elsewhere in `Token`. The
  example's assertions now pin what is actually emitted, so the fix shows up
  as a change there. Reported to botopink-lang.

- **The rule model** (1.0.10-beta front `56-emilia-cascade-and-output`, steps 1–3). New
  module `modules/emilia/src/output.bp`, declared `pub mod output;` in `root.bp` and
  listed in the member manifest's `files`. It declares **no external** and touches no
  host cell. `Rule(layer, atRules, selector, declarations, important)` replaces the
  declaration string a token used to lower to; `Block(header, body)` carries a rule that
  is not a style rule (today only `@keyframes`); `Sheet(rules, blocks)` is what a token
  list produces; `Variant(atRule, selector)` is what a modifier is. A `selector` is a
  **nesting template** carrying exactly one `&`, so every row of the variant reference
  is one template — `&:hover`, `[dir="rtl"] &`, `:is(& > *)`,
  `&:is(:where(.group):hover *)` — and a selector with **no** `&` is a literal selector,
  which is how the theme writes `:root` and front 55 writes its reset. Constructors:
  `emptySheet()`, `declSheet(decls)` (empty string → empty sheet), `staticSheet(layer,
  selector, decls)`, `blockSheet(header, body)`, `mergeSheet(a, b)`, `declarationsOf(s)`,
  `layerNames()`. `nestVariant(s, v)` wraps a sheet in a variant and `markImportant(s)`
  sets the flag on every rule; both return new values, records being immutable.
  `nestVariant` **refuses** a variant selector that does not carry exactly one `&`,
  naming the selector: with none the variant replaces the rule it was meant to wrap,
  with two it duplicates it. There is no argument that relaxes it.

- **CSS nesting runs inner-`&`-first, and the front's own spec had it backwards**
  (front `56-emilia-cascade-and-output`, step 2). `&:hover { &::before { … } }`
  flattens to `&:hover::before`: the **inner** rule's `&` is what the **outer**
  variant's selector replaces. The spec's Mechanism says the opposite ("the new
  selector is `v.selector` with its single `&` replaced by the rule's current
  selector"), which renders every nested pair backwards and contradicts the spec's
  own acceptance list. `nestRule` implements the acceptance list, and the two nesting
  tests pin both orders so it cannot drift back.

- **The codec** (front `56-emilia-cascade-and-output`, step 4). A host cell stores one
  string per class, so `encodeSheet(s)`/`decodeSheet(raw)` carry a `Sheet` through it:
  records joined by `"\n"` and tagged `R`/`B`, fields by `"\t"`, the `atRules` list by
  `"\r"`. `encodeSheet(emptySheet())` is `""` and `decodeSheet("")` is `emptySheet()`.
  That no rendered declaration carries one of the three is the assumption the codec
  rests on, so it is **checked** rather than assumed: `carriesSeparator(s)` is a value,
  and a test walks the dispatcher output and the theme's own strings through it.

- **Options and the render** (front `56-emilia-cascade-and-output`, step 6).
  `Options(theme, base, prefix, important, layers)` with `defaultOptions()` and the five
  `withTheme`/`withBase`/`withPrefix`/`withImportant`/`withLayers` updaters.
  `renderRule(className, r, o)` substitutes `"." + prefix + className` for the rule's
  `&`, wraps the declarations in the rule's at-rules **outermost-first**, and appends
  `!important` **per declaration** when either the rule or the options say so; a literal
  selector renders literally and the prefix never reaches it. `renderDocument(raw, o)`
  emits `@layer theme, base, components, utilities;` first when `layers == true` and **no
  `@layer` token at all** when it is false, then each non-empty layer in that order — the
  theme as a `:root` rule, `o.base` (front 55's reset, **opt-in** here rather than
  opt-out), the components layer, then the registered classes in registration order with,
  inside one class, the unconditioned rules before the conditioned ones — and finally the
  `@keyframes` blocks, outside every layer and deduplicated by header. Measured: 42/42
  (`output.bp`) + 37/37 (`theme.bp`) + 6/6 (`spacing.bp`) + 17/17 (`emilia.bp`) on
  commonJS and on erlang.

- **`Array.reverse()` mutates its receiver on commonJS and does not on erlang** (found
  by front `56-emilia-cascade-and-output`). `val rev = xs.reverse();` leaves `xs`
  reversed on commonJS and untouched on erlang, so any fold over a reversed list is a
  silent target divergence. `wrapAtRules` therefore maps the list twice — the opening
  braces in order, the closing braces after the body — instead of folding a reversed
  copy. Reported to botopink-lang as a codegen defect alongside the two front 54 found.

- **The theme** (1.0.10-beta front `54-emilia-theme`, step 1). New module
  `modules/emilia/src/theme.bp`, declared `pub mod theme;` in `root.bp` and listed in
  the member manifest's `files`. A theme is a **flat `ThemeEntry[]`**, not nineteen
  record fields: `ThemeEntry(name, value)`, `Theme(entries, keyframes, darkMode)`,
  `DarkMode { Media, Class(name), Attribute(name, value) }`, and the `Ns` enum naming
  the nineteen namespaces. `nsPrefix(ns)` is the **only** place a custom-property
  prefix string is written — `--color-`, `--font-`, …, `@keyframes ` — and
  `Ns.Spacing` maps to `--spacing` with no trailing dash, because it is a single
  variable rather than a family. `allNamespaces()` lists the nineteen in declaration
  order. Measured: `botopink test` in `modules/emilia/` is 5/5 (`theme.bp`) + 17/17
  (`emilia.bp`) on commonJS and on erlang.

- **`defaultTheme()`** (front `54-emilia-theme`, step 2). The stock theme, in declaration
  order: `--spacing`, the five `--breakpoint-*` (rem, not px), the eight `--radius-*`,
  `--color-black`/`--color-white`, the thirteen `--text-*` sizes each paired with its
  `--text-*--line-height` (26 entries), the seven `--shadow-*` (`sm`–`xl` two-shadow), the
  thirteen `--container-*`, the four `--animate-*`, and the four `keyframes` bodies (`spin`,
  `ping`, `pulse`, `bounce`) in their own list, because a keyframes value is a rule body and
  cannot live inside `:root`. Entry ORDER is a contract — emilia's class names are content
  hashes, so a reordered theme is a different document. The palette is **front 33's**: only
  black and white ship here, and front 33 hands over `paletteEntries() -> ThemeEntry[]` for
  `extend(defaultTheme(), paletteEntries())`. Measured: 14/14 + 17/17 on both targets.

- **extend · override · clear · empty · read** (front `54-emilia-theme`, step 3).
  `extendTheme(th, entries)` adds entries and **overrides in place** — a name already
  present keeps its position, because the entry order is a content-hash contract;
  `clearNamespace(th, ns)` is the `--color-*: initial` reset, `emptyTheme()` the
  `--*: initial` one, `namespace(th, ns)` reads one namespace back, `themeValue(th,
  name)` resolves a name to its literal value (`""` when absent) and `themeVar(name)`
  gives the `var(--name)` reference form every utility emits. `extendTheme` **refuses**
  an entry whose name matches no known prefix, naming it; there is no permissive mode
  and no argument that relaxes it. Two spellings the language forced: the composer is
  `extendTheme`, because `extend` is a keyword (`Name extend Type { … }`), and a lambda
  body that is a bare `if` expression is bound to a `val` first, because the bare form
  lowers to `undefined` on commonJS. Measured: 24/24 + 17/17 on both targets.

- **`spacing(n)`** (front `54-emilia-theme`, step 4). New module
  `modules/emilia/src/spacing.bp`. `spacing(4)` answers `calc(var(--spacing) * 4)`,
  `spacing(0)` answers `0`, `spacing(-4)` answers `calc(var(--spacing) * -4)`, and
  `spacingHalf(n)` covers the closed set of fractional steps. **emilia never resolves a
  spacing value**: emitting the `rem` literal would be byte-different from upstream for
  every spacing utility and would make a consumer's `--spacing: 4px` override silently
  ineffective. `i32` rather than `f64`, so the emitted string never depends on a
  backend's float formatting. Measured: 6/6 + 24/24 + 17/17 on both targets.

- **The static custom-property block and the dark-mode strategy** (front
  `54-emilia-theme`, steps 5 and 6). `themeCss(th)` renders the theme as the BODY of a
  `:root` rule — `name:value` joined with `;`, in the theme's own order, which is
  `defaultTheme()`'s declaration order followed by each `extendTheme`'s. The block is
  **always the whole theme** (`@theme static` semantics): tree-shaking needs a
  whole-program pass over every `emilia()` call site and emilia hashes per call site, so
  the tree-shaken form is out of scope for this milestone — not a bug to file later.
  `keyframeCss(th)` hands back the four `@keyframes` bodies, which cannot live inside
  `:root`; each carries the bare animation name and a brace-balanced body, so front 56
  writes `nsPrefix(Ns.Keyframes) + name + value` and never spells the at-rule.
  `darkAtRule(th)` / `darkSelector(th)` turn the strategy into the two pieces front 34
  needs: `@media (prefers-color-scheme: dark)` + `&` for `Media`, `""` +
  `&:where(.dark, .dark *)` for `Class`, `""` +
  `&:where([data-theme=dark], [data-theme=dark] *)` for `Attribute`. `withDarkMode(th,
  mode)` swaps the strategy and changes nothing else. Verified: `themeCss(defaultTheme())`
  and the four keyframes blocks are **byte-identical to the 70 expected lines** of the
  milestone's own `05-emilia/test-snap.md`. Measured: 6/6 + 36/36 + 17/17 on both targets.

- **A theme is a module** (front `54-emilia-theme`, step 7). Upstream shares a theme
  between projects by importing a CSS file; in botopink a theme is a function in a module,
  so sharing it is an ordinary package dependency. New workspace member
  `examples/emilia-theme/` (application, `emilia` via `{ "workspace": true }` and nothing
  else) defines a brand theme in one function, clears the stock colour namespace, composes
  a second package's entries over the default, reads values back through `themeValue`, and
  styles a card with `spacing(4)`. It is the proof that the front 54 surface crosses a
  package boundary through `from "emilia"`. 6/6 on commonJS and on erlang; it builds and
  runs. The flushed document does not yet carry the theme — that is front 56's
  `withTheme`/`flushWith`. `theme.bp` carries the same composition assertion inline, so
  the front's own suite covers it without the example. Measured: 6/6 (spacing.bp) + 37/37
  (theme.bp) + 17/17 (emilia.bp) in `modules/emilia/`, 6/6 in `examples/emilia-theme/`,
  both targets.

- **The repository is a workspace** (`02-packaging` step 2; decisions 75 and 76 of
  1.0.10-beta). `botopink.json` at the root is `{ name, version, description, targets
  [commonJS, erlang], workspaces ["modules/*", "examples/*"] }` — no `src`, `files`,
  `target` or `dependencies`; `botopink build/test` there is the located refusal naming
  the members (`emilia, emilia-card`). The core moved with `git mv` to
  `modules/emilia/` (the three `src/*.bp`; emilia has no `test/` — every test is inline)
  and its manifest carries `name emilia`, `entry root.bp`, `target commonJS`,
  `targets [commonJS, erlang]` and `files: [root.bp, tokens.bp, emilia.bp]` — a library
  member without `files` is `✗ ships nothing`. `examples/emilia-card` is the member
  `emilia-card`, depending on `emilia` via `{ "workspace": true }` instead of the git
  form; `jhonstart` keeps `{ git, branch }` until jhonstart is a workspace too and a
  `path` to `…/modules/jhonstart` exists. The pre-commit runner is workspace-aware:
  `botopink test` in every `modules/*/` member, then the examples gate. Measured: the
  core 17/17 on commonJS and on erlang at its new path; `botopink-lib-test` prints one
  row per member and no umbrella row. `examples/emilia-card` joins
  `scripts/known-broken-examples.txt` — jhonstart `feat` (`13d1672`) does not compile
  against botopink-lang `feat` (`hooks.bp:109 use-without-context-effect`), which is
  jhonstart's `fix/context` front, not emilia's; the example's own 4 tests still pass.

- **Section types by path** (botopink-lang front 06 N28/C8): the 27
  sub-dispatcher annotations name their section by path — `TokenText` is
  `Token.Text`, `TokenTextSize` is `Token.Text.Size`, … The flat names were
  never declared; the checker accepted them until pattern bindings became
  typed. Tests 17/17 on commonJS and erlang; `emilia-card` builds and its 4
  tests pass (it still fails at run time on the known commonJS sibling
  `require("../module")`, as before).

- **1.0.3 surface** (botopink-lang front 12): `pub enum Token` is
  `pub type Token { … }` (sections and payload variants unchanged). Tests 17/17 on
  commonJS and erlang; `emilia-card` builds and its 4 tests pass (it still fails at
  run time on the known commonJS sibling `require("../module")`, as before).
  `botopink format` is not applied: it reorders the variants and sections.

- The erlang target runs: `register`, `flushSheet` and `hashHex` carry an
  `compiler.external(.Erlang)` form (process-dictionary sheet, the same djb2 hash), so
  `botopink test --target erlang` passes 17/17 instead of stopping at
  `MissingExternalTarget`; `botopink.json` lists `erlang` in `targets`.

- The examples gate no longer aborts silently on a `scripts/known-broken-examples.txt`
  holding only comments or blank lines: the runner reads the list with `awk`, whose
  "no entry" is not a failure under `set -euo pipefail`.

- `examples/emilia-card` builds again: its jhonstart builder calls pass `attrs`
  explicitly (parameter defaults are not applied yet), it leaves
  `scripts/known-broken-examples.txt`, and CI checks jhonstart out beside
  emilia so the examples gate can resolve it.

- **MIT license.** `LICENSE` (`Copyright (c) 2026 Eric Fillipe and botopink
  contributors`) backs the README's License section, which now points at it.

- The gate builds the examples: after `botopink test`, the pre-commit hook
  and CI run `botopink build` in every `examples/*/` with a `botopink.json`;
  `scripts/known-broken-examples.txt` lists the ones allowed to fail, and a
  listed example that builds fails the gate.
- **A gate.** `scripts/git-hooks/pre-commit` (conflict markers, then
  `botopink test`; install with `git config core.hooksPath
  scripts/git-hooks`) and `.github/workflows/test.yml` (`test-libs --lib
  emilia --target commonJS`), matching the sibling libraries. Before this,
  a commit ran nothing locally or in CI.
- **ecosystem-and-snap-tail F2** — `tokenToCss` exhaustive dispatch +
  modifier composition re-pinned for the V1 nested-section enum (the
  V0 surface dropped during the `3f77623` WIP migration). Every top-
  level section (`Text/Font/Color/Bg/Pad/Margin/Layout/Flex/Border/
  Effect`) routes to its typed sub-dispatcher; every modifier
  (`Hover/Focus/Active/Md/Lg/Xl`) recurses through the new
  `tokensToCss` helper to compose the inner CSS inside the
  pseudo/media wrapper. 11 in-file smoke tests pin the V1 leaf set +
  modifier composition. The full `emilia(tokens)/flush()` public
  surface remains deferred (the `register`/`flushSheet`/`hashHex`
  declares + `pub fn emilia/flush` need re-authoring under a follow-
  up commit pair, blocked on the V0→V1 example migration).

  GOTCHA pinned: in `case ARM(field) -> ...`, the bind name maps to
  the variant's **literal field name**. Section-auto-synth variants
  carry `_inner` (use `_inner`); user-declared payloads use the
  declared name (`Hover(inner: Token[])` → `Hover(inner)`, not
  `Hover(_inner)`). Mixing the two issues `undefined.map` at runtime.

## Unreleased — v0.beta.20

- **F0** lib stand-up (v0 surface): `Token` enum with 3 sections
  (Text/Color/Bg/Pad — V0 flat variants pending the `enum-sections`
  language extension) + 6 modifier variants (`Hover`, `Focus`,
  `Active`, `Md`, `Lg`, `Xl`), `emilia(tokens: Token[]) -> string`
  entry point, `flush() -> string` per-render serializer, the
  `Stylesheet` host cell (commonJS only at v1 — folded into
  `emilia.bp` because cross-module `#[compiler.external(.<target>(...))]` symbol imports don't
  lower at v0). Two-module package (`tokens` + `emilia`); `botopink
  test` green over 9 in-file blocks.
- **F2** `tokenToCss` exhaustive `case` covering every v0 variant.
- **F3** modifier composition — `Hover`/`Focus`/`Active` produce
  `:pseudo{…}` blocks; `Md`/`Lg`/`Xl` produce
  `@media(min-width:Xpx){…}` blocks; modifiers nest
  (`Md(Hover(...))`).
- **F4** `flush()` per-render semantics — register collects, flush
  serialises + clears, two consecutive flushes emit two independent
  blocks.
- **F5** runnable [`examples/emilia-card/`](examples/emilia-card/) — a
  small jhonstart page composed with three emilia class names + a
  modifier in the body style; depends on `jhonstart` + `emilia`; 4
  in-file `test {}` green.
- Docs sweep: README, AGENTS, docs, this CHANGELOG.

### Deferred (v0.beta.21+)

- F0 second half — two generic jhonstart hooks
  (annotation-on-builder, `[name]={expr}` html attribute). Block on
  the jhonstart `Element` attribute slot + a call-site decorator
  mechanism in the compiler.
- F1 full `Token` shape — `enum-sections` language extension lands the
  nested section paths (`.Color.Red.500`, `.Pad.X.4`).
- `stylesheet.bp` split — cross-module external import parity.
- erlang/beam `Stylesheet` port.

## v0.0.1 — Seed

- Repository created under `botopink/emilia`. Tracked from
  `botopink/projects` (workspace root) as a git submodule on the
  `feat` branch. Intent + design surface lived in
  `tasks/v0.beta.19/specs/emilia.md`, later updated to
  `tasks/v0.beta.20/specs/ecosystem.md` (v20 ecosystem-expansion
  keystone).
