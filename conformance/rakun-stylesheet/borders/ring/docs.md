# ring

{src/main.bp}

### Ring — the box-shadow half of a focus ring

**Every shadow and ring token writes ONE channel and the same reader**, upstream
v4's five-channel `box-shadow`:
`var(--tw-inset-shadow, 0 0 transparent), var(--tw-inset-ring-shadow, 0 0 transparent), var(--tw-ring-offset-shadow, 0 0 transparent), var(--tw-ring-shadow, 0 0 transparent), var(--tw-shadow, 0 0 transparent)`.
So `[.Ring.W.2, .Effect.Shadow.Md]` draws both — and a lone ring draws at all:
each channel falls back to a null shadow, where an unset channel would otherwise
invalidate the whole declaration.

A ring **composes with a shadow rather than overwriting it**: the `box-shadow`
declaration *lists* `var(--tw-shadow)` instead of writing a shadow of its own,
so a `Ring` token and an `Effect.Shadow` token in the same list both reach the
output. Token order is class identity, so swapping the two is a different class
— which is the sharpest case [contract 4](#stable-hashes--sites-collapse) has.

`.Ring.W.1` is upstream's bare `ring`. **The v4 default is 1px**, where v3's was
3px.

> **Verified and unverified.** The custom property names, the inset flag and the
> v4 default width were checked against upstream. The composed `box-shadow`
> list and the whole `ring-offset-*` family were **not** confirmed — v4's
> documentation no longer carries `ring-offset-*` at all. Both are declared
> because the surface asks for them, and both are recorded here rather than
> presented as transcribed.
