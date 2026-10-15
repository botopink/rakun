# config_load

{src/main.bp}

The reference text this cell shows (from [`../docs.md`](../docs.md), § [configurationProperties("my.service")]):

> `rkConfigLoad()` is the whole load: eight sources in order (command line,
> `RAKUN_APPLICATION_JSON`, environment, profile documents, base documents,
> configuration trees, `rkSetProp`, declared defaults), profiles resolved and
> written to `rakun.profiles.resolved`, and one refusal naming the input when a
> location, an import, a document or a profile group is wrong.
>
> `${key}` and `${key:default}` resolve at load time; `${random.uuid}`,
> `${random.int[1024,65536]}` and friends resolve per REFERENCE through
> `rkValue(key)`. Typed readers — `rkPropBool`, `rkPropIntOr`, `rkPropFloat`,
> `rkPropList`, `rkPropDuration`, `rkPropSize` — carry the declared default as
> their second argument and try the kebab, camel and `SCREAMING_SNAKE` spellings
> of a key before giving up.
>
> Three formats are read — `.properties`, `.json` and a documented YAML subset —
> plus `configtree:` directories (one file per key). A nested JSON object flattens
> to dot keys (`server.port`) and an array to indexed keys (`a[0]`). A YAML
> construct outside the subset (anchor, alias, flow style, block scalar, tag) is a
> located refusal naming the file and the line, never a silent mis-parse. See
> [`AGENTS.md`](../../../../AGENTS.md) § Externalized configuration for the table.

## Measured

The cell carries an `application.yaml` naming an active profile.
