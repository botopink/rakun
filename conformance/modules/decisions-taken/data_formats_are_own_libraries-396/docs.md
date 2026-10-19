# Decision 396 — Markdown, YAML and JSON are three libraries of their own — `markdown`, `yaml`, `json` (`botopink/{markdown,yaml,json}` at `repository/{markdown,yaml,json}`, 326's rule) — and std knows nothing of JSON.

The example reads a content file the way rakun-ssr's content layer does, and each format in it comes from its own library. The frontmatter is YAML, and `yaml`'s reader turns it into `json`'s `Json`, so the title and the tags are read with `Json`'s own methods, `field`, `str` and `items`. The program prints `Three formats json yaml markdown`. The body is Markdown, and `markdown`'s `parse` answers that library's own tree, which `headings` walks into a table of contents: `1:Three formats, 2:Why`. The feed entry is written back as JSON with `json`'s `object`, `array` and `quote`, and the last line is that JSON text, holding the title and the two section slugs.

The program imports only the terminal from std. A rakun package that reads these formats declares `json`, `yaml` and `markdown` as dependencies in its manifest, because std has no JSON module to reach for. rakun's own YAML reader in `config.bp` gave `yaml` its seed and goes once `yaml` holds it, and rakun-ssr maps `markdown`'s tree to rakun-bpp's `Element`.

Cells in this repository that prove it: none yet. `json` and `yaml` hold no code until 151 s1 and 152 s1 (144 B-27 moves std's `json.bp` out), and until then the example does not build; `markdown`'s reader is in place.

[draft/main.bp](draft/main.bp)
