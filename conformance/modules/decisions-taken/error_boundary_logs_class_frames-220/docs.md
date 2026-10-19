# Decision 220 — The runtime hands the error boundary the caught error's class and frames (erlang: `Class` and the stacktrace; node: `err

The example is a rakun-bpp error boundary around the route segment `app/blog/[slug]/page`, whose page throws. The runtime catches the raise and hands the boundary its class and its frames — on erlang the exception's `Class` and stacktrace, on node `err.name` and `err.stack` — beside the message. The boundary writes one error record with log's `logError(module, errorClass, message, topFrames, fields)`, `module` being the boundary's route segment, and renders its fallback from the digest `logError` answers. A sink installed by the program prints that record: the message in full, `error.module=app/blog/[slug]/page`, a class and frames given, and the digest; the rendered fallback holds the same digest and not the message. The frames are normalised by log's rule (194), line numbers stripped, so the same fault hit at other lines answers the same digest; the boundary computes no digest of its own.

Departure: rakun-bpp's boundary hands its fallback only the message and digests it with std's `hash.contentHash` (`digestOf`); it neither receives the class and frames nor calls log's `logError`, and rakun-bpp declares no `log` dependency, so the sink prints nothing.

Cells in this repository that bear on it: [error_boundary](../../../rakun-bpp/error-boundaries/error_boundary/docs.md), the boundary's catch and fallback as built. log's own draft of this decision is the boundary seen from log.

[draft/main.bp](draft/main.bp)
