# Decision 677 — The root package is a package like any other: every module under its `src/` is in the program, imported or not, and the manifest's `"entry"` says only where execution starts.

The program is two files of the root package. `draft/jobs.bp` declares the module `cleaner` with `#[rakun.module]`, a `component fn` that prints `cleaner starts` when it starts and hangs `cleaner stops` off `onStop`. `draft/main.bp` never imports `jobs`: the manifest's `"entry"` (absent, so `main.bp`) only says that `main` is read from `main.bp`, and every other file under `src/` is in the program all the same — checked, compiled, linked, its `compiler.init` executor run before `main` in init order. So `rakun.boot()` finds `cleaner` in the registry and starts it, `rakun.registry.find("cleaner")` answers it, and `rakun.stop()` runs its handler: the program prints `cleaner starts`, `cleaner`, `cleaner stops`. A dependency's modules join the program by the same rule; `test/` and the conformance cells are not `src/` and stay out. A forgotten file with a type error under `src/` fails the build instead of vanishing. A library declares no `"entry"` at all (733).

Cells in this repository that prove it: none yet. rakun's plug-and-play cell `rakun/plug-and-play/boot_modules` boots modules of its dependencies, which are imported; the root package's unimported module arrives with front 165 s5 (plug-and-play) over 660's step of 144.

[draft/main.bp](draft/main.bp)
[draft/jobs.bp](draft/jobs.bp)
