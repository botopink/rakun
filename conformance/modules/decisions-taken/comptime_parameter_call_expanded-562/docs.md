# Decision 562 — A function whose body reads a `comptime` parameter's `.value` is expanded at its call site: what depends on build data runs at build, what reaches a run-time value is emitted there as run-time code

The program declares two rakun modules that start only on request (`#[rakun.module(.Manual)]`) and starts them through `startAll`, a function whose only parameter is `comptime`. Because every parameter is known at build, the call `startAll(["web", "admin"])` in `main` is replaced by the code the body emits: the loop over the names and the `label` concatenation run at build, and each statement that reaches a run-time value, `terminal.print(label)` and `rakun.start(n)`, is written into `main` once per name, in order, with `"starting web"` / `"web"` and then `"starting admin"` / `"admin"` as constants. `startAll` keeps no run-time body; nothing iterates the list when the program runs. The program prints `starting web`, `starting admin` and `2`.

Two calls are refused at build, located. Passing a run-time variable (`val names = …; startAll(names);`) is `comptime-arg-not-known`. A loop bound or a condition in the body that needs a run-time value (`if (rakun.start(n).isError()) …`) is refused at that condition, naming the value it would need. A function that declares a run-time parameter beside its `comptime` ones is never expanded: its `comptime` parameters make it a specialisation. The decision is written for rakun's `boot()` over the program's modules, which is expanded the same way in the root package's `main`.

Cells in this repository that prove it: none yet. `rakun/plug-and-play/boot_modules` boots modules through the run-time registry; the expanded `rakun.boot()` comes with 144 B-99 and front 165 s5 / s7.

[draft/main.bp](draft/main.bp)
