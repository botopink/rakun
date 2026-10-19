# Decision 665 — `compiler.find` goes: no catalogue is read at build; the registry each decorator writes with `compiler.init` is the one way to gather the declarations marked with it.

Three health endpoints marked `#[endpoint(…)]`, gathered the one way left: each registers itself. The decorator records an `Endpoint` meta on its declaration and compiles an executor with `compiler.init`; inside it, `compiler.meta<Endpoint>(decl)` is a build read, folded into the executor, so each entry carries its own id and whether it is critical. At run time the executors have filled rakun's catalogue (`rkCatalogueStore`), in source order, and the program reads it with `rkCatalogueNames()`: `db!`, `disk`, `mail`.

Nothing reads the set of marked declarations at build: there is no `compiler.find(with: endpoint)` and no `@TypeInfo.all`. A rule over the whole set — exactly one `#[theme]`, say — is the registering executor's refusal at init, before `main`, not a build error.

Cells of this repository that prove it: none yet. The container cells (`rakun/container/boot_sequence`, `rakun/container/context`, `rakun/web/usage`, …) still gather beans through `@TypeInfo.all`; front 165 s10 rewrites them as registries.

[draft/main.bp](draft/main.bp)
