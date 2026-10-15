# mask-raw

{src/main.bp}

#### Arbitrary values — `rawShadow`, `rawTextShadow`, `rawMaskImage`

Upstream's `shadow-[…]`, `text-shadow-[…]` and `mask-image-[…]` are
**top-level variants with a payload**, not leaves inside their section: a
payload leaf nested inside an enum section cannot be constructed by any
spelling (see *`Color.Hex("#abc")` is declared and unconstructible*). The name
keeps the path it would have had, flattened.

The three wrappers exist because a **leading-dot path followed by a payload
call does not carry the typed-array context** — `[.EffectShadowRaw("…")]` does
not parse. `Token.EffectShadowRaw(value: "…")` in full does, and so does a call
to one of the wrappers; they produce the same token and the same class.

The reference prints no arbitrary-value form; each was measured against
upstream v4. `rawShadow` is upstream's shape — the value goes into
`--tw-shadow` and the rule writes the five-channel `box-shadow` reader, so it
composes with a ring as `Effect.Shadow` does. `rawTextShadow` and
`rawMaskImage` set upstream's property (`text-shadow`, `mask-image`) and stay
**provisional** in one respect, marked at their arm: upstream rewrites a colour
inside a text shadow through `--tw-text-shadow-color`, which a raw string does
not.
