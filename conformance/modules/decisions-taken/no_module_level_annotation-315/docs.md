# Decision 315 — No module-level annotation.

The example declares two rakun modules in one file. Each one is marked on its own declaration: `#[rakun.module]` on `store`, and `#[rakun.module(lifecycle: Lifecycle.Manual)]` on `admin`, with an argument of its own. The behaviour the two share, the start banner, is not an annotation of the file. It is a module-level `val`, `banner`, that each body calls.

`rakun.boot()` starts `store`, the one `.Eager` module, which prints `[store] starts`. The registry holds both modules (`2`), and `rakun.start("admin")` starts the manual one, which prints `[admin] starts`.

A file-wide form such as `#![rakun.module]` at the top of the module, or rakun's internal marker written once for every function, is a parse error. An annotation always annotates the declaration that follows it, so a behaviour wanted on several functions is written on each of them (`#[useCache] pub fn posts() …`) or bound once in a `val` that the functions call.

Cells in this repository that prove it: `rakun/plug-and-play/boot_modules` (each `#[rakun.module]` on its own function, with its own lifecycle).

[draft/main.bp](draft/main.bp)
