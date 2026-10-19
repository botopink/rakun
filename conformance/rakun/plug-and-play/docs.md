# Plug-and-play

> Package: [`rakun`](../docs.md) · index: [`../../docs.md`](../../docs.md)

A package declares what it contributes at its root: one component function per
module, marked `#[rakun.module]`, answering `Component<Service>`. The
decorator's executor writes `Module(name, lifecycle, make)` into the run-time
`registry` before `main` (decisions 575 (3), 580), `make` the annotated function
itself (581 (2)), so the program's `main` only writes `rakun.boot();`.

{boot_modules/src/main.bp}

- `Lifecycle` says when `boot()` starts a module: `.Eager` at boot (the
  default), `.Lazy(afterMs:)` once `afterMs` milliseconds have passed since boot
  began, `.Manual` only through `rakun.start(name)`, which answers
  `Result<void, string>` (an error naming a module no package declares).
- A module runs as a component over a `ServiceScope`, the render scope without
  a DOM (decisions 388, 504), so its body `use`s hooks: `inject(name)` starts the
  module of that name once, on demand, and answers its `Service` — a module
  starts after everything it injects, so the boot order is the dependency
  order —, and `onStop(f)` runs `f` at `rakun.stop()`, the last registered
  first.
- `rakun.registry.find(name)` answers the `?Module` of that name.
- A program overrides a package's defaults with a typed record, a `val` marked
  `#[rakun.config]` whose type is written; the package reads it with
  `configOf("<Type>", <defaults>)`, its own defaults when the program declares
  none. A field the record does not declare is the ordinary build error:

{config_wrong_field/src/main.bp}

`#[rakun.module]` goes on a `component fn() -> Component<Service>` only; any
other declaration is refused at the annotation:

{module_not_a_component/src/main.bp}

The program still imports a name from each package whose modules it starts
(`import {alpha.web} from "alpha";`): a module of a declared dependency that no
module imports joins no init list, so its executors never run. The two build
errors of plug-and-play — one thing contributed by two packages, a package
another requires and the program lacks — are not cells yet: a decorator body
that reads the catalogue makes its module one no module may import.
