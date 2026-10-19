# Decision 239 — The parser refuses `$stringify` in every template, std included; std's `Array.join` Erlang template is written without i

The example is the refused program. `statusLine` is a host-bound `declare fn` whose Erlang and JavaScript templates turn the status of a rakun `Response` into text with `$stringify($0)`. The parser refuses the program at the first template that writes `$stringify`, located inside the template text: a template has `$0`, `$1`, … for its arguments and nothing that converts a value behind the program's back.

The conversion belongs to botopink, where it is typed: `"status " + Response.ok("hi").status.toString()` needs no host template at all.

Cells of this repository that prove it: none yet. No template of rakun's host bindings (`modules/rakun/src/runtime.bp`, the `rkSsr*` cells of `modules/rakun-app/src/ssr.bp`) writes `$stringify`; the refusal is the parser's.

[draft/main.bp](draft/main.bp)
