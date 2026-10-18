# config_wrong_field

{src/main.bp}

A `#[rakun.config]` override is a typed record: a field `ZetaConfig` does not
declare is the ordinary build error at the field. `zeta` is `boot_modules`'s
fixture package.
