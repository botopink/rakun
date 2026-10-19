# Decision 580 — An executor is a statement of its module's body at its declaration's position: one init list, source order.

The example interleaves rakun's `#[rakun.module]` declarations with module-level `val`s that read
the module registry. Each `#[rakun.module]` contributes an executor — the registration of the
annotated function — and that executor is a statement of the module's body at the declaration's
position, not something appended after the body. So the module's `val`s and the two executors run
as one list, top to bottom, before `main`.

`atStart` is read before either module is declared and holds nothing; `afterStore` is read after
`store`'s registration and holds `store`; `afterWeb` holds `store,web`. `main` prints `0 store
store,web` and boots the two modules in that order. Moving `val afterStore` above `store` would
change only that line's answer: the order is the source's, and no flag chooses another.

Proving cells: `conformance/rakun/plug-and-play/boot_modules` (the modules registered by their
executors before `main`, booted in registry order).

[draft/main.bp](draft/main.bp)
