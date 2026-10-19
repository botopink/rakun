# Decision 733 — (a): a library has no `"entry"` — the key is an executable's alone, refused in a library's manifest.

The program consumes `rakun`, a library, and shows the one place an `"entry"` belongs. Every file under the library's `src/` is a module reached by its path — `import {http.Response} from "rakun";`, `import {version_set.rakunVersion} from "rakun";` — so a library has nothing for an `"entry"` to name: it has no `main`. The program is the executable, and its manifest is the one whose `"entry"` (absent here, so `main.bp`) says where `main` is read from. It prints `200 hello` and `0.0.1`.

The refused half is a library manifest that writes the key: a `botopink.json` whose package has no `main` and that declares `"entry": "root.bp"` is refused with `manifest-entry-in-library`, located at the key and naming the package. rakun's own package manifests still write `"entry": "root.bp"` today (`modules/rakun/botopink.json` among them); front 165 s5 deletes the key from every library manifest, and the refusal is 144's (592's step).

Cells in this repository that prove it: none yet; rakun's manifests lose the key with front 165 s5.

[draft/main.bp](draft/main.bp)
