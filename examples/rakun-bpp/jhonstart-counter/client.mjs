// jhonstart-counter — the built example under the client runtime, on node.
//
// `botopink build` emits `out/main.js`, which binds `state` to
// `out/rakun-bpp/hooks.js` (the server pass). The client build resolves
// `rakun-bpp/hooks` to `rakun-bpp/client_runtime.mjs` (decision 88 of
// 1.0.10-beta; the bundler's step, front 68) — under node the same substitution
// is a `require.cache` seed before `main.js` loads. `Counter` then runs under
// the runtime's loop and its `use state(0)` cell re-renders on `set`:
//
//   botopink build && node client.mjs      (see the sidecar note below)
//   <div><p>count: 0</p><span>non-negative</span></div>   ← main() of the built program, at load
//   <div><p>count: 0</p><span>non-negative</span></div>   ← Counter, first render
//   <div><p>count: 3</p><span>non-negative</span></div>   ← after set(3)
//   <div><p>count: -2</p><span>negative</span></div>      ← after set(-2)
//
// `out/rakun-bpp/client_runtime.mjs` is shipped by `botopink build` (the G2
// sidecar step) from whatever `libDirByName` answers for the name `rakun-bpp`
// across the library ROOTS (`shipMjsSidecars`, botopink-lang
// `modules/compiler-cli/src/cli/libs.zig`) — NOT through this project's
// resolved `{ "rakun-bpp": { "workspace": true } }` dependency. That is a known
// defect owned by front `00 · 10-cli-residuals`, and a miss is SILENT: the
// build still exits 0, the sidecar is simply absent, and only `node client.mjs`
// fails to resolve it.
//
// In this workspace the lookup is by MANIFEST NAME (not by directory basename,
// since front 02-packaging step 1), so the member `modules/rakun-bpp/` is found
// and the sidecar ships — which it did NOT before the core moved out of the
// root `src/`, a flat package never being a root of its own. It does not ship
// while two directories on the roots
// both declare the name `rakun-bpp` — a `.tasks/` worktree beside the main
// `repository/rakun-bpp` checkout: `resolveDuplicateNames` marks both entries
// and `libDirByName` returns null. From such a worktree, copy it by hand:
//
//   botopink build \
//     && cp ../../modules/rakun-bpp/src/client_runtime.mjs out/rakun-bpp/ \
//     && node client.mjs

import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import * as runtime from "./out/rakun-bpp/client_runtime.mjs";

const require = createRequire(import.meta.url);
const out = join(dirname(fileURLToPath(import.meta.url)), "out");

// The substitution: `rakun-bpp/hooks` → `rakun-bpp/client_runtime.mjs`.
const hooks = join(out, "rakun-bpp", "hooks.js");
require.cache[hooks] = { id: hooks, filename: hooks, loaded: true, exports: runtime };

const { Counter } = require(join(out, "main.js"));
const { renderToString } = require(join(out, "rakun-bpp", "element.js"));

const handle = runtime.render(Counter, (tree) => console.log(renderToString(tree)));
handle.cells[0].set(3); // `Counter`'s `use state(0)` cell
handle.flush();
handle.cells[0].set(-2);
handle.flush();
handle.dispose();
