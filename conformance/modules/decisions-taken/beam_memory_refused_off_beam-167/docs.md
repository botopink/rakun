# Decision 167 — A target that is not the BEAM (commonJS, wasm) refuses `#[@BeamMemory]`: a module-level `var` carrying `#[@BeamMemory.<m

The example counts the requests a rakun server has served in one module-level `var` marked
`#[compiler.beamMemory(.Ets)]`: three concurrent request processes each add one, and `main` prints `3`,
because the counter lives in an ETS table owned past each process, not in the process that wrote it.
This package builds for erlang only, as every rakun package does, so the annotation is in force. The
same program in a package that also declares `commonJS` (or `wasm`) is refused there at the `var`,
located at the annotation: those targets have no BEAM memory, and the refusal is the ordinary one, so
a cell that shows `compiler.beamMemory` simply leaves those targets out of its `"targets"` instead of being
exempted from the audit.

Proving cells: none in this repository; the refusal is the compiler's (`17-beam-memory`), proved by
botopink-lang's cells.

[draft/main.bp](draft/main.bp)
