# configuration_properties

The reference text this cell shows (from `conformance/docs.md`, § Configuration):

> `#[value("key")]` reads the property table; `config.bp` fills it. A whole record
> binds at once with `#[configurationProperties]`:
>
> The record is then injectable by type into any `#[service]`, and every key it
> declares lands in the run-time catalogue.

## Measured

The cell sets the properties with `rkSetProp` (no file) and reads the bound record through `MyService.make()`. The emitted binder calls the typed readers (`rkValueOr`, `rkPropBool`, …) by name, so the module imports them.
