# Decision 194 — One error-digest scheme with one implementation: the first 16 hex of `strongHash` over `module|errorClass|message|top

A rakun handler that fails. `charge(-5)` calls `log`'s `Logger.logError` once: it writes the error record — the full message, the class, the module, the frames, and the amount as a field — and answers the digest, the first 16 hex of the hash over `module|errorClass|message|topFrames`. The response is a 500 whose body is `clientErrorBody(digest)`, the digest and nothing else. The program installs a sink that prints the record it receives, so the record and its digest appear first, then the response. The same fault reported from another build — other line numbers, no fourth frame, another argument value — has the same digest: `errorDigest(…)` with those frames gives the same body (`true`), and a digest is 16 characters long.

No library computes a digest any other way: rakun's `logging/digest.bp` and rakun-bpp's `digestOf` are the copies this decision deletes.

Cells of this repository that prove it: none of the scheme. `rakun-bpp/error-boundaries/error_boundary` compares two digests of one fault, through rakun-bpp's own `digestOf`, which goes.

[draft/main.bp](draft/main.bp)
