# config_document

The reference text this cell shows (from `conformance/docs.md`, § [configurationProperties("my.service")]):

> The record is then injectable by type into any `#[service]`, and every key it
> declares lands in the run-time catalogue.
>
> `rkConfigLoad()` is the whole load: eight sources in order (command line,
> `RAKUN_APPLICATION_JSON`, environment, profile documents, base documents,
> configuration trees, `rkSetProp`, declared defaults), profiles resolved and
> written to `rakun.profiles.resolved`, and one refusal naming the input when a
> location, an import, a document or a profile group is wrong.

## Measured

The cell carries the `application.yaml` the example reads.
