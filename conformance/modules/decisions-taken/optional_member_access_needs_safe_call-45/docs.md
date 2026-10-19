# Decision 45 — A member access on a `?T` is an error naming `?.`

This is the refused program. The package declares one module, `web`, with `#[rakun.module]`, and `main` boots it. Then it asks rakun's registry for the module by name. `rakun.registry.find("web")` answers `?Module`, because a name no package declares has no module, and the program reads `.name` straight off that optional. The checker refuses the read at `.name`, and the message names `?.` as the spelling to write.

The fix is `rakun.registry.find("web")?.name`, which is a `?string` and is read with `??` (`?? "no module"`), the way `boot_modules`' `main` tests `store != null` before reading `store.name`. The refusal holds for every receiver typed `?T`: a labelled tuple taken out of an array by `at`, a record, a type of a library. It is the same on every target, because nothing reaches a backend.

Cells in this repository that prove it: none yet. The refused read is the checker's. rakun's `rakun/plug-and-play/boot_modules` writes the accepted form, narrowing by `!= null` before the read, and the refusal cell for rakun's registry comes with front 165 s7, the workspace's Conformance step.

[draft/main.bp](draft/main.bp)
