# boot_modules

{src/main.bp}

The program declares `zeta` and `alpha` and overrides `zeta`'s config. `boot()`
starts `web` (`.Eager`), whose `use inject("store")` starts `store` first, once,
over the program's `ZetaConfig`; `warmup` (`.Lazy(afterMs: 1)`) follows; `admin`
(`.Manual`) starts at `rakun.start("admin")`, and a name no package declares is
an error. `rakun.stop()` runs the `onStop` handlers, the last registered first.
The fixture packages are the cell's `deps/zeta` and `deps/alpha`
(`{deps/zeta/src/root.bp}`, `{deps/alpha/src/root.bp}`).
