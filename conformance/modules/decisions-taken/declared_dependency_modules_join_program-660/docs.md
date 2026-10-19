# Decision 660 — (a): every module of every declared dependency is part of the program — it joins the build and its `compiler.init` executors join the init list whether or not anything imports it — and the init list is ordered by dependency resolution: a package that depends on nothing first, a package after every package it depends on, the ones with most dependencies last; two packages at the same level in the order their dependant's `botopink.json` lists them; inside a package, 580's order (modules in dependency order, declarations in source order).

The program imports only from `rakun`, and its manifest — the workspace's — declares every rakun package. `rakun-metrics` is one of them and nothing imports it, yet its `#[component] MeterRegistry` is part of the program: its module joins the build and its `compiler.init` executor, the `rkScan("MeterRegistry")` the decorator compiles, joins the init list. The application's own `#[service] Greeter` registers too, and after it: `rakun-metrics` depends on `rakun` and the application depends on both, so the init list runs the packages in dependency order and the application last. The program prints `true` three times — `MeterRegistry` was scanned, `Greeter` was scanned, `MeterRegistry` before `Greeter` — then `hello, rakun` from the resolved service.

Nothing in the program is a work-around import: an `import` brings names into scope and nothing else; being declared is what makes a package's registrations run.

Cells of this repository that prove it: none yet — rakun's plug-and-play cells still import the modules they need to register (`rakun/plug-and-play`); they lose those imports with front 165 s5 and 144 B-137.

[draft/main.bp](draft/main.bp)
