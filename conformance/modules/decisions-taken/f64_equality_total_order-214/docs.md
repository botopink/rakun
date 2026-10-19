# Decision 214 — `f64` under `==` is a total order (Java's `Double.compare`): `0.0 == -0.0` is `false` and `NaN == NaN` is `true`, bare o

The example reads a sampling weight from rakun's configuration. `rkPropFloat("rakun.probe.weight", 0.0)` answers the fallback, `+0.0`, because the program sets no such key, and `negated` is the same value times `-1.0`, a `-0.0` computed at run time. Under `==` the two zeros are two values: `configured == negated` prints `false` and `!=` prints `true`. The same key read twice is equal (`true`), and `-0.0` is equal to itself (`true`).

The ordering operators are untouched. `negated < configured` is `false` and `negated <= configured` is `true`, as IEEE orders them.

Equality goes into structures without changing. A `Weight` record, a tuple, an array and a `Reading.Sampled` variant that hold the two zeros are unequal (`false` four times). `Reading.Sampled(value: configured)` against a literal `0.0` is equal (`true`).

The NaN half (`NaN == NaN` is `true`) is not in the program. rakun is erlang-only (decision 113), and the BEAM never produces a NaN: `0.0 / 0.0` raises `badarith`. The commonJS and wasm backends meet it elsewhere.

Cells in this repository that prove it: none yet. The rule is every backend's equality. rakun's config readers (`rkPropFloat`) come into its conformance with front 165 s7, the workspace's Conformance step.

[draft/main.bp](draft/main.bp)
