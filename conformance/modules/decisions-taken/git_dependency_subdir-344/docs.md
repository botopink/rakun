# Decision 344 — A git dependency may name a package inside its repository: `"subdir"`.

`botopink/rakun` is one repository holding many packages, and the program uses two of them: `Response` from `rakun` and the CORS policy of `rakun-service`. Its manifest declares each as a git dependency on the same repository at the same `ref`, each naming its package with `"subdir"` — `"rakun": {"git": "https://github.com/botopink/rakun", "ref": "v1.0", "subdir": "modules/rakun"}` and the same with `"subdir": "modules/rakun-service"`. `bpmp` clones the repository once at that `ref`, reads each package at its `subdir`, and resolves `rakun-service`'s own dependency on `rakun` inside the same checkout, so both come at one version. The program prints `200`, `true` for the allowed origin and `false` for the other.

The manifest is refused, located at the field, for a `subdir` without `git`, a `subdir` that is absolute or leaves the checkout with `..`, a `subdir` with no `botopink.json` or whose manifest is a workspace, and for one repository named at two `ref`s — the message naming both dependencies.

This draft builds against the workspace's path dependencies; the manifest with the `subdir` dependencies is the one `promote` writes beside it (front 166 s4).

Cells of this repository that prove it: none yet. rakun's packages reach each other by `{ "workspace": true }` inside the repository; a consumer's `subdir` dependency is rakun 73's and `02/98` step 4's.

[draft/main.bp](draft/main.bp)
