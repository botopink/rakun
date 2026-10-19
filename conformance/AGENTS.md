# rakun — conformance/

- `docs.md` — the workspace's reference: the packages' index, the suite's layout, the decisions' index.
- `<package>/<feature>/<cell>/` — the reference's cells (decision 548), listed in `botopink.json`.
- `modules/decisions-taken/<slug>-<N>/` — front 166's decision cells (decision 651: the subtree is that front's alone):
  one per code-bearing row of `../decisions-taken.md`, a `docs.md` (first line generated) and, in phase 1,
  `draft/main.bp` (decision 649; no `src/`, no manifest, so `botopink cell check` finds no cell there); kept by
  `scripts/decision-cells.py` of the meta repository and its CI check 7.
- `modules/botopink.json` — the decision drafts' workspace manifest (`"workspaces": ["*"]`, `erlang` — the target every
  package of the workspace declares —, each package by `"path": "../../modules/<package>"`, the libraries `actions` and `http` by `git` as the packages declare
  theirs), read by
  `decision-cells.py compile` for the drafts' dependencies; it is not listed in `botopink.json` and holds no cell.
