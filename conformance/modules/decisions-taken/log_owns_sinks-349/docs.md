# Decision 349 — `log` owns the sinks; rakun and onze only integrate.

rakun's part in logging, and nothing more. The typed configuration record `LoggingConfig` holds a choice — the file, the root level, a level for `rakun.web` — and `install` turns it into `log`'s sink: `Levels` with a per-name threshold, `log`'s `fileSink` with rotation over a `LogFile`, installed with `setSink`, then `captureRuntimeReports()` so the runtime's own crash and supervisor reports go through the same sink. The program then logs three records: `rakun.web` at debug passes its own threshold, `app` at debug is below the root's info and is dropped, `app` at info passes. It prints `installed`, then `true`, `false`, `true` for what the file holds.

The sinks — console, file, per-name levels, the runtime capture — are `log`'s, one behaviour on every target; rakun configures and installs them, and of its logging keeps only the correlation id.

Cells of this repository that prove it: none yet — rakun still carries its own logging copies under `rakun/src/logging/`; front 04-rakun/17 moves them to `log`.

[draft/main.bp](draft/main.bp)
