# imports

{src/main.bp}

The reference text this cell shows (from [`../docs.md`](../docs.md), § `#[imports]`):

> Spring's `@Import`: a bean is registered for each named type, so a configuration
> record in a module the application does not otherwise reference is still wired.
> Each named type must already have a factory — from a stereotype, a `#[bean]`
> method or a `#[provides]` function — and a name with none does not compile,
> naming both the type and the configuration that asked for it.
>
> Spring's `@ComponentScan(basePackages=…)` has no analogue and needs none: an
> additional scan root in botopink is a `pub mod` line.

## Measured

The named type must carry a factory of a stereotype (`#[service]`); a type with only a `#[bean]` method does not compile under `#[imports]`, so the cell imports `Vault` and keeps `Wallet` as the `#[bean]`.
