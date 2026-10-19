# Decision 407 — For now, `import {testing.snapshots} from "std"` keeps the checker's plain unknown-module error; the pointer to `snap` is documentation.

A program that still reaches for the snapshot module std once had. It imports `testing.snapshots` from std to record the classification table `rakun-ssr` answers. The program is refused at the import with the checker's plain answer for any missing std module, `error: unknown "std" module 'testing' in import`: the compiler names no library and std keeps no module whose only job is to fail.

The fix is documentation, not a diagnostic: `snap` is the snapshot engine, `import {assertAs} from "snap";` with `"snap"` in the manifest's `"dependencies"`, as `rakun`'s own suites write it (`modules/rakun-ssr/test/types_test.bp`).

Cells of this repository that prove it: none — the refusal is the compiler's; the pointer lives in `libs/std/AGENTS.md` and `snap`'s `AGENTS.md` (`20-snap` step 0).

[draft/main.bp](draft/main.bp)
